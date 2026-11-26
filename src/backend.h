#pragma once
#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QProcess>
#include <QVariantList>
class Backend : public QObject {
  Q_OBJECT
  Q_PROPERTY(QVariantList messages READ messages NOTIFY changed)
  Q_PROPERTY(QVariantList conversations READ conversations NOTIFY changed)
  Q_PROPERTY(QString selection READ selection NOTIFY changed)
  Q_PROPERTY(QString error READ error NOTIFY changed)
  Q_PROPERTY(bool busy READ busy NOTIFY changed)
  Q_PROPERTY(QString provider READ provider WRITE setProvider NOTIFY changed)
  Q_PROPERTY(QString model READ model WRITE setModel NOTIFY changed)
  Q_PROPERTY(QStringList models READ models NOTIFY changed)
  Q_PROPERTY(QString effort READ effort WRITE setEffort NOTIFY changed)
  Q_PROPERTY(QStringList efforts READ efforts NOTIFY changed)
public:
  explicit Backend(QString storage = {}, QObject *parent = nullptr);
  ~Backend() override;
  QVariantList messages() const { return m_messages.toVariantList(); }
  QVariantList conversations() const;
  QString selection() const { return m_selection; }
  QString error() const { return m_error; }
  bool busy() const { return m_busy; }
  QString provider() const { return m_provider; }
  QString model() const { return m_model; }
  QStringList models() const { return m_models; }
  QString effort() const { return efforts().contains(m_effort) ? m_effort : QString(); }
  QStringList efforts() const;
  void setProvider(QString p);
  void setModel(QString m);
  void setEffort(QString effort);
  Q_INVOKABLE void send(QString text);
  Q_INVOKABLE void cancel();
  Q_INVOKABLE void newChat(QString selection = {}, bool explain = false);
  Q_INVOKABLE void load(QString id);
  Q_INVOKABLE void remove(QString id);
  Q_INVOKABLE void refreshModels();
  Q_INVOKABLE void copy(QString text);
  Q_INVOKABLE void login();
  Q_INVOKABLE void openData();
  void reportError(QString message) {
    m_error = message;
    emit changed();
  }
  void consume(QJsonObject event);
  QString prompt() const;
  static QStringList arguments(QString provider, QString model,
                               QString effort = {});
signals:
  void changed();

private:
  void save();
  void read();
  void finish(int code);
  void append(QString role, QString content);
  QString m_storage, m_selection, m_error, m_id, m_provider = "Codex", m_model;
  QString m_effort;
  QStringList m_models;
  QHash<QString, QStringList> m_modelEfforts;
  QJsonArray m_messages, m_history;
  QProcess m_process, m_modelProcess;
  QByteArray m_buffer, m_stderr;
  QString m_answer;
  bool m_busy = false, m_cancelled = false;
};
