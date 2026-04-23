#ifndef COREMANAGER_H
#define COREMANAGER_H

#include <QObject>
#include <QProcess>
#include <QVariantList>
#include <QDateTime>
#include <QTimer>
#include <QVariantMap>
#include "backstage.h"
#include "networkmanager.h"
#include "logger.h"
#include "../sensor/dht11.h"
#include "../sensor/lightsensor.h"
#include "../sensor/zpsensor.h"
#include "../sensor/mq135sensor.h"

class CoreManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString tempStr READ tempStr NOTIFY valueSig)
    Q_PROPERTY(QString humStr READ humStr NOTIFY valueSig)
    Q_PROPERTY(QString lightStr READ lightStr NOTIFY valueSig)
    Q_PROPERTY(QString zp01Str READ zp01Str NOTIFY valueSig)
    Q_PROPERTY(QString mq135Str READ mq135Str NOTIFY valueSig)
    Q_PROPERTY(QList<double> tempBuffer READ tempBuffer NOTIFY bufferSig)
    Q_PROPERTY(QList<double> humBuffer READ humBuffer NOTIFY bufferSig)
    Q_PROPERTY(QList<double> lightBuffer READ lightBuffer NOTIFY bufferSig)
    Q_PROPERTY(QList<double> zp01Buffer READ zp01Buffer NOTIFY bufferSig)
    Q_PROPERTY(QList<double> mq135Buffer READ mq135Buffer NOTIFY bufferSig)
    Q_PROPERTY(QVariantList predictedTempList READ predictedTempList NOTIFY predictionUpdated)
    Q_PROPERTY(QVariantList predictedHumList READ predictedHumList NOTIFY predictionUpdated)
    Q_PROPERTY(QVariantList predictedLightList READ predictedLightList NOTIFY predictionUpdated)
    Q_PROPERTY(QVariantList predictedMq135List READ predictedMq135List NOTIFY predictionUpdated)
    Q_PROPERTY(QVariantList predictedZp01List READ predictedZp01List NOTIFY predictionUpdated)
    Q_PROPERTY(bool isAiBusy READ isAiBusy NOTIFY aiStatusChanged)
    Q_PROPERTY(qint64 baseTime READ baseTime NOTIFY predictionUpdated)
    Q_PROPERTY(bool isSensorActive READ isSensorActive NOTIFY sensorStatusChanged)
    Q_PROPERTY(bool isNetworkConnected READ isNetworkConnected NOTIFY networkStatusChanged)
    Q_PROPERTY(QVariantList logList READ logList NOTIFY logListUpdated)

public:
    explicit CoreManager(QObject *parent = nullptr);
    ~CoreManager() override;

    Q_INVOKABLE void setSensorActive(int id, bool active);
    Q_INVOKABLE void setSensorInterval(int id, int sec);
    Q_INVOKABLE bool getSensorActive(int id);
    Q_INVOKABLE int getSensorInterval(int id);
    Q_INVOKABLE int getMsPerPoint() const;

    // 手动清空历史缓冲区（用于24:00重置）
    Q_INVOKABLE void clearHistoryBuffer();

    // 手动启动 AI 预测
    Q_INVOKABLE void runPrediction();

    QString tempStr() const;
    QString humStr() const;
    QString lightStr() const;
    QString zp01Str() const;
    QString mq135Str() const;
    QList<double> tempBuffer() const;
    QList<double> humBuffer() const;
    QList<double> lightBuffer() const;
    QList<double> zp01Buffer() const;
    QList<double> mq135Buffer() const;
    QVariantList predictedTempList() const;
    QVariantList predictedHumList() const;
    QVariantList predictedLightList() const;
    QVariantList predictedMq135List() const;
    QVariantList predictedZp01List() const;
    qint64 baseTime() const;
    bool isAiBusy() const;
    bool isSensorActive() const;
    bool isNetworkConnected() const;
    QVariantList logList() const;

signals:
    void valueSig();
    void bufferSig();
    void sensorSig(int id);
    void predictionUpdated();
    void aiStatusChanged();
    void sensorStatusChanged();
    void networkStatusChanged(bool connected);
    void errorOccurred(const QString &error);
    void logListUpdated();

private slots:
    void onBackstageDataChanged();
    void handleProcessOutput();
    void handleProcessError(QProcess::ProcessError error);
    void handleSensorError(const QString &error);
    void handleBackstageError(const QString &error);
    void handleLogAdded(const QString& timestamp, const QString& level, const QString& module, const QString& message, const QString& color);

private:
    Backstage *m_backstage;
    NetworkManager *m_networkManager;
    DHT11 *m_dht11;
    LightSensor *m_lightSensor;
    ZPSensor *m_zpSensor;
    MQ135Sensor *m_mq135Sensor;
    QProcess* m_predictProcess;
    QVariantList m_predictedTempList;
    QVariantList m_predictedHumList;
    QVariantList m_predictedLightList;
    QVariantList m_predictedMq135List;
    QVariantList m_predictedZp01List;
    QVariantList m_logList;
    qint64 m_baseTime;
    bool m_isAiBusy;
    QByteArray m_aiStdoutBuffer;
    QByteArray m_aiStderrBuffer;
};

#endif // COREMANAGER_H
