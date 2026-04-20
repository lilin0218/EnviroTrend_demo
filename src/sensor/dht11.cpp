#include "dht11.h"
#include "../core/logger.h"
#include <QtMath>

DHT11::DHT11(QObject *parent)
    : QThread(parent),
      m_fd(-1),
      m_useHardware(false),
      m_active(true),
      m_interval(1000),
      m_tick(0.0)
{
}

DHT11::~DHT11() {
    m_active = false;
    quit();
    wait();
#ifdef Q_OS_LINUX
    if (m_fd != -1) {
        ::close(m_fd);
        m_fd = -1;
    }
#endif
}

bool DHT11::init() {
#ifdef Q_OS_LINUX
    m_fd = ::open("/dev/dht11", O_RDONLY);
    if (m_fd >= 0) {
        m_useHardware = true;
        Logger::instance()->info("DHT11", "Hardware initialized on /dev/dht11");
        return true;
    }
    Logger::instance()->debug("DHT11", "Failed to open /dev/dht11, falling back to mock mode");
#endif

    m_useHardware = false;
    Logger::instance()->info("DHT11", "Running in mock mode (simulator)");
    return true;
}

void DHT11::readData() {
    if (m_useHardware) {
#ifdef Q_OS_LINUX
        if (m_fd < 0) {
            emit errorOccurred("Invalid file descriptor");
            return;
        }

        char rawBuf[32] = {0};
        ssize_t bytesRead = ::read(m_fd, rawBuf, sizeof(rawBuf));

        if (bytesRead < 5) {
            emit errorOccurred("Insufficient data read from sensor");
            return;
        }

        double humInt  = static_cast<unsigned char>(rawBuf[0]);
        double humDec  = static_cast<unsigned char>(rawBuf[1]);
        double tempInt = static_cast<unsigned char>(rawBuf[2]);
        double tempDec = static_cast<unsigned char>(rawBuf[3]);

        double humidity = humInt + (humDec / 10.0);
        double temperature = tempInt + (tempDec / 10.0);

        QVariantMap data;
        data["humidity"] = humidity;
        data["temperature"] = temperature;
        data["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        data["hardware"] = true;
        emit valueSig(data);
#endif
    } else {
        m_tick += 0.1;
        double mockTemp = 22.0 + 3.0 * qSin(m_tick);
        double mockHumi = 50.0 + 5.0 * qCos(m_tick);

        QVariantMap data;
        data["humidity"] = mockHumi;
        data["temperature"] = mockTemp;
        data["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        data["hardware"] = false;
        emit valueSig(data);
    }
}

void DHT11::run() {
    if (!init()) {
        emit errorOccurred("Failed to initialize sensor");
        return;
    }

    while (m_active) {
        readData();
        msleep(static_cast<unsigned long>(m_interval));
    }
}

void DHT11::setActive(bool active) {
    if (active && !isRunning()) {
        start();
    }
    m_active = active;
}

bool DHT11::getActive() {
    return m_active;
}

void DHT11::setInterval(int interval) {
    if (interval >= 100 && interval <= 5000) {
        m_interval = interval;
    } else {
        emit errorOccurred("Interval must be between 100 and 5000 ms");
    }
}

int DHT11::getInterval() {
    return m_interval;
}

bool DHT11::useHardware() const {
    return m_useHardware;
}

// AbstractSensor 接口实现
void DHT11::startSensor() {
    setActive(true);
}

void DHT11::stopSensor() {
    setActive(false);
}
