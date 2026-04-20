#include "zpsensor.h"
#include "../core/logger.h"
#include <QtMath>

ZPSensor::ZPSensor(QObject *parent)
    : QThread(parent),
      m_useHardware(false),
      m_active(true),
      m_interval(1000),
      m_tick(0.0)
{
}

ZPSensor::~ZPSensor() {
    m_active = false;
    quit();
    wait();
}

bool ZPSensor::init() {
#ifdef Q_OS_LINUX
    if (access("/sys/bus/iio/devices/iio:device0/in_voltage1_raw", R_OK) == 0) {
        m_useHardware = true;
        Logger::instance()->info("ZP", "Hardware initialized on ADC channel 1");
        return true;
    }
    Logger::instance()->debug("ZP", "Failed to access ADC channel 1, falling back to mock mode");
#endif

    m_useHardware = false;
    Logger::instance()->info("ZP", "Running in mock mode (simulator)");
    return true;
}

int ZPSensor::readADC(const char *path) {
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

void ZPSensor::readData() {
    if (m_useHardware) {
#ifdef Q_OS_LINUX
        int raw = readADC("/sys/bus/iio/devices/iio:device0/in_voltage1_raw");
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

        // 模拟 PM2.5 和 PM10 值
        float pm25 = voltage * 50.0;
        float pm10 = pm25 * 1.5;

        QVariantMap data;
        data["pm25"] = pm25;
        data["pm10"] = pm10;
        data["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        data["hardware"] = true;
        emit valueSig(data);
#endif
    } else {
        m_tick += 0.1;
        double mockPM25 = 10.0 + 20.0 * qSin(m_tick);
        double mockPM10 = mockPM25 * 1.5;

        QVariantMap data;
        data["pm25"] = mockPM25;
        data["pm10"] = mockPM10;
        data["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        data["hardware"] = false;
        emit valueSig(data);
    }
}

void ZPSensor::run() {
    if (!init()) {
        emit errorOccurred("Failed to initialize sensor");
        return;
    }

    while (m_active) {
        readData();
        msleep(static_cast<unsigned long>(m_interval));
    }
}

void ZPSensor::setActive(bool active) {
    if (active && !isRunning()) {
        start();
    }
    m_active = active;
}

bool ZPSensor::getActive() {
    return m_active;
}

void ZPSensor::setInterval(int interval) {
    if (interval >= 100 && interval <= 5000) {
        m_interval = interval;
    } else {
        emit errorOccurred("Interval must be between 100 and 5000 ms");
    }
}

int ZPSensor::getInterval() {
    return m_interval;
}

bool ZPSensor::useHardware() const {
    return m_useHardware;
}

// 自定义方法
void ZPSensor::startSensor() {
    setActive(true);
}

void ZPSensor::stopSensor() {
    setActive(false);
}
