#ifndef LIGHTSENSOR_H
#define LIGHTSENSOR_H

#include <QThread>
#include <QVariantMap>
#include <QDateTime>
#include <QDebug>

#ifdef Q_OS_LINUX
#include <fcntl.h>
#include <unistd.h>
#endif

#include "abstractsensor.h"

class LightSensor : public QThread, public AbstractSensor {
    Q_OBJECT
public:
    explicit LightSensor(QObject *parent = nullptr);
    ~LightSensor() override;

    bool init() override;
    void readData() override;
    void setActive(bool active) override;
    bool getActive() override;
    void setInterval(int interval) override;
    int getInterval() override;
    bool useHardware() const;

    // 自定义方法
    void startSensor();
    void stopSensor();

signals:
    void valueSig(const QVariantMap &data);
    void errorOccurred(const QString &msg);

protected:
    void run() override;

private:
    bool m_useHardware;
    bool m_active;
    int m_interval;
    double m_tick;
    int readADC(const char *path);
};

#endif // LIGHTSENSOR_H
