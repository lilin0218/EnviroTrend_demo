#include "mq135sensor.h"
#include "../core/logger.h"
#include <QtMath>

MQ135Sensor::MQ135Sensor(QObject *parent)
    : QThread(parent),
      m_useHardware(false),
      m_active(true),
      m_interval(1000),
      m_tick(0.0)
{
}

MQ135Sensor::~MQ135Sensor() {
    m_active = false;
    quit();
    wait();
}

bool MQ135Sensor::init() {
#ifdef Q_OS_LINUX
    if (access("/sys/bus/iio/devices/iio:device0/in_voltage3_raw", R_OK) == 0) {
        m_useHardware = true;
        Logger::instance()->info("MQ135", "Hardware initialized on ADC channel 3");
        return true;
    }
    Logger::instance()->debug("MQ135", "Failed to access ADC channel 3, falling back to mock mode");
#endif

    m_useHardware = false;
    Logger::instance()->info("MQ135", "Running in mock mode (simulator)");
    return true;
}

int MQ135Sensor::readADC(const char *path) {
#ifdef Q_OS_LINUX
    FILE *fp = fopen(path, "r");
    if (!fp) return -1;

    int val;
    int ret = fscanf(fp, "%d", &val);
    fclose(fp);

    return (ret == 1) ? val : -1;
#else
    return -1;
#endif
}

void MQ135Sensor::readData() {
    if (m_useHardware) {
#ifdef Q_OS_LINUX
        int raw = readADC("/sys/bus/iio/devices/iio:device0/in_voltage3_raw");
        if (raw < 0) {
            emit errorOccurred("Failed to read ADC value");
            return;
        }

        // 读取缩放因子
        FILE *fp = fopen("/sys/bus/iio/devices/iio:device0/in_voltage_scale", "r");
        if (!fp) {
            emit errorOccurred("Failed to read ADC scale");
            return;
        }

        float scale;
        int ret = fscanf(fp, "%f", &scale);
        fclose(fp);

        if (ret != 1 || scale <= 0) {
            emit errorOccurred("Failed to read valid ADC scale");
            return;
        }

        float voltage = raw * scale / 1000.0;

        // 计算有害气体浓度 (ppm)
        float gas = voltage * 200.0;

        QVariantMap data;
        data["gas"] = gas;
        data["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        data["hardware"] = true;
        emit valueSig(data);
#endif
    } else {
        m_tick += 0.1;
        double mockGas = 30.0 + 20.0 * qSin(m_tick);

        QVariantMap data;
        data["gas"] = mockGas;
        data["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        data["hardware"] = false;
        emit valueSig(data);
    }
}

void MQ135Sensor::run() {
    if (!init()) {
        emit errorOccurred("Failed to initialize sensor");
        return;
    }

    while (m_active) {
        readData();
        msleep(static_cast<unsigned long>(m_interval));
    }
}

void MQ135Sensor::setActive(bool active) {
    if (active && !isRunning()) {
        start();
    }
    m_active = active;
}

bool MQ135Sensor::getActive() {
    return m_active;
}

void MQ135Sensor::setInterval(int interval) {
    if (interval >= 100 && interval <= 5000) {
        m_interval = interval;
    } else {
        emit errorOccurred("Interval must be between 100 and 5000 ms");
    }
}

int MQ135Sensor::getInterval() {
    return m_interval;
}

bool MQ135Sensor::useHardware() const {
    return m_useHardware;
}

// 自定义方法
void MQ135Sensor::startSensor() {
    setActive(true);
}

void MQ135Sensor::stopSensor() {
    setActive(false);
}
