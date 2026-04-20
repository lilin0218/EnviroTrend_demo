#ifndef DHT11_H
#define DHT11_H

#include <QThread>
#include <QVariantMap>
#include <QDateTime>
#include <QDebug>

#ifdef Q_OS_LINUX
#include <fcntl.h>
#include <unistd.h>
#endif

#include "abstractsensor.h"

class DHT11 : public QThread, public AbstractSensor {
    Q_OBJECT
public:
    explicit DHT11(QObject *parent = nullptr);
    ~DHT11() override;

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
    bool init();
    void readData();

    int m_fd;
    bool m_useHardware;
    bool m_active;
    int m_interval;
    double m_tick;
};

#endif // DHT11_H
