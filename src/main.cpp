#include "backend.h"
#include "translator.h"
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalServer>
#include <QLocalSocket>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QScreen>
#include <QSettings>
#include <QTimer>
#include <unistd.h>
int main(int argc, char **argv) {
  QGuiApplication app(argc, argv);
  app.setApplicationName("omachat");
  app.setOrganizationName("Omachat");
  app.setDesktopFileName("omachat");
  app.setApplicationVersion("0.2.2");
  auto args = app.arguments();
  QJsonObject request;
  if (args.contains("--request-stdin")) {
    QFile f;
    if (!f.open(stdin, QIODevice::ReadOnly))
      return 1;
    auto bytes = f.read(140000);
    request = QJsonDocument::fromJson(bytes).object();
  } else if (args.contains("--selection")) {
    QProcess p;
    p.start("wl-paste", {"--primary", "--no-newline"});
    if (p.waitForFinished(700) && p.exitCode() == 0) {
      auto data = p.readAllStandardOutput();
      if (data.size() <= 32768)
        request["text"] = QString::fromUtf8(data);
      else
        request["error"] = "Selection exceeds 32 KiB.";
    } else
      p.kill();
  }
  request["explain"] =
      request["explain"].toBool() || args.contains("--explain");
  QString socket = QDir::tempPath() + "/omachat-" + QString::number(getuid()) +
                   (args.contains("--screenshot") ? "-preview.sock" : ".sock");
  QLocalSocket client;
  client.connectToServer(socket);
  if (client.waitForConnected(200)) {
    client.write(QJsonDocument(request).toJson(QJsonDocument::Compact) + "\n");
    client.waitForBytesWritten(1000);
    return 0;
  }
  QLocalServer server;
  server.setSocketOptions(QLocalServer::UserAccessOption);
  QLocalServer::removeServer(socket);
  if (!server.listen(socket))
    return 1;
  QQuickStyle::setStyle("Basic");
  Translator translator;
  app.installTranslator(&translator);
  Backend backend;
  QQmlApplicationEngine engine;
  engine.rootContext()->setContextProperty("backend", &backend);
  engine.rootContext()->setContextProperty("translator", &translator);
  QObject::connect(&translator, &Translator::changed, &engine,
                   &QQmlEngine::retranslate);
  engine.load(QUrl("qrc:/Main.qml"));
  if (engine.rootObjects().isEmpty())
    return 1;
  auto window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
  QSettings geometry;
  QTimer positionPoll;
  QProcess positionQuery;
  QObject::connect(&positionPoll, &QTimer::timeout, &app, [&] {
    if (window->isVisible() && positionQuery.state() == QProcess::NotRunning)
      positionQuery.start("hyprctl", {"-j", "clients"});
  });
  QObject::connect(&positionQuery, &QProcess::finished, &app,
                   [&](int code, QProcess::ExitStatus) {
                     if (code != 0)
                       return;
                     for (auto v : QJsonDocument::fromJson(
                                       positionQuery.readAllStandardOutput())
                                       .array()) {
                       auto o = v.toObject();
                       if (o["class"] != "omachat")
                         continue;
                       auto at = o["at"].toArray();
                       if (at.size() == 2) {
                         geometry.setValue("position/x", at[0].toInt());
                         geometry.setValue("position/y", at[1].toInt());
                       }
                     }
                   });
  QTimer::singleShot(600, &app, [&] {
    if (!geometry.contains("position/x")) {
      positionPoll.start(2500);
      return;
    }
    QPoint pos(geometry.value("position/x").toInt(),
               geometry.value("position/y").toInt());
    QRect bounds = window->screen()->availableGeometry();
    for (auto screen : app.screens())
      if (screen->availableGeometry().contains(pos)) {
        bounds = screen->availableGeometry();
        break;
      }
    pos.setX(qBound(bounds.left(), pos.x(),
                    qMax(bounds.left(), bounds.right() - window->width())));
    pos.setY(qBound(bounds.top(), pos.y(),
                    qMax(bounds.top(), bounds.bottom() - window->height())));
    auto mover = new QProcess(&app);
    QObject::connect(mover, &QProcess::finished, mover, &QObject::deleteLater);
    mover->start("hyprctl",
                 {"dispatch", QString("hl.dsp.window.move({x=%1,y=%2,relative="
                                      "false,window=\"class:^omachat$\"})")
                                  .arg(pos.x())
                                  .arg(pos.y())});
    positionPoll.start(2500);
  });

  auto apply = [&](QJsonObject r) {
    if (backend.busy()) {
      backend.reportError(
          QObject::tr("Wait for the current answer or press Stop before "
                      "attaching another selection."));
      window->show();
      window->requestActivate();
      return;
    }
    if (r.contains("text"))
      backend.newChat(r["text"].toString(), r["explain"].toBool());
    window->show();
    window->raise();
    window->requestActivate();
  };
  QObject::connect(&server, &QLocalServer::newConnection, &app, [&] {
    while (server.hasPendingConnections()) {
      auto s = server.nextPendingConnection();
      s->setProperty("buffer", QByteArray());
      QObject::connect(s, &QLocalSocket::readyRead, &app, [&, s] {
        auto b = s->property("buffer").toByteArray() + s->readAll();
        if (b.size() > 140000) {
          s->disconnectFromServer();
          return;
        }
        if (b.contains('\n')) {
          apply(QJsonDocument::fromJson(b.left(b.indexOf('\n'))).object());
          s->disconnectFromServer();
        } else
          s->setProperty("buffer", b);
      });
      QObject::connect(s, &QLocalSocket::disconnected, s,
                       &QObject::deleteLater);
    }
  });
  apply(request);
  if (args.contains("--screenshot"))
    QTimer::singleShot(1500, &app, [&] {
      window->grabWindow().save(args.value(args.indexOf("--screenshot") + 1));
      app.quit();
    });
  return app.exec();
}
