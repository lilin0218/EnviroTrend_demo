#ifndef LOGGER_H
#define LOGGER_H

#include <QObject>
#include <QMutex>
#include <QFile>
#include <QString>

class Logger : public QObject {
    Q_OBJECT

public:
    enum LogLevel {
        DEBUG,
        INFO,
        WARNING,
        ERROR,
        CRITICAL
    };
    Q_ENUM(LogLevel)

    static Logger* instance();

    void debug(const QString& module, const QString& message);
    void info(const QString& module, const QString& message);
    void warning(const QString& module, const QString& message);
    void error(const QString& module, const QString& message);
    void critical(const QString& module, const QString& message);

    void setLogLevel(LogLevel level);
    static QString levelToString(LogLevel level);
    static QString levelToColor(LogLevel level);
    
    QList<QVariantMap> getLogHistory() const;

signals:
    void logAdded(const QString& timestamp, const QString& level, const QString& module, const QString& message, const QString& color);

private:
    explicit Logger(QObject *parent = nullptr);
    ~Logger();

    void writeLog(LogLevel level, const QString& module, const QString& message);

    QMutex m_mutex;
    QFile m_logFile;
    LogLevel m_logLevel;
    QList<QVariantMap> m_logHistory;
};

#endif // LOGGER_H