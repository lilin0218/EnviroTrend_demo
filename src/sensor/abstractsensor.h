#ifndef ABSTRACTSENSOR_H
#define ABSTRACTSENSOR_H

#include <QVariantMap>
#include <QString>

// 改为纯粹的 C++ 类，不继承 QObject
class AbstractSensor {
public:
    virtual ~AbstractSensor() {}

    // 依然保留这些接口
    virtual bool init() = 0;
    virtual void readData() = 0;
    virtual void setActive(bool active) = 0;
    virtual bool getActive() = 0;
    virtual void setInterval(int interval) = 0; // ms
    virtual int getInterval() = 0; // ms

    // 注意：因为不继承 QObject 了，这里不能定义 signals。
    // 我们把信号的定义权交给具体的子类（如 DHT11）
};

#endif
