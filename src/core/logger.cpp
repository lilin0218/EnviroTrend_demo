#include "logger.h"
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QMutexLocker>
#include <QTextStream>
#include <QDebug>
#include <iostream>

Logger* Logger::instance() {
    static Logger instance;
    return &instance;
}

Logger::Logger(QObject *parent) : QObject(parent), m_logLevel(DEBUG) {
    QString appDir = QCoreApplication::applicationDirPath();
    QString logDir = appDir + "/logFile";
    QDir dir(appDir);
    
    if (!dir.exists("logFile")) {
        dir.mkdir("logFile");
    }
    
    QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    QString logPath = logDir + "/app_" + timestamp + ".log";
    m_logFile.setFileName(logPath);
    m_logFile.open(QIODevice::WriteOnly | QIODevice::Text);
    
    if (m_logFile.isOpen()) {
        QString startupMsg = QString("[%1] [INFO] [SYSTEM] Logger initialized, log file: %2\n")
                            .arg(QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz"))
                            .arg(logPath);
        QTextStream stream(&m_logFile);
        stream << startupMsg;
        stream.flush();
    }
}

Logger::~Logger() {
    if (m_logFile.isOpen()) {
        m_logFile.close();
    }
}

void Logger::setLogLevel(LogLevel level) {
    QMutexLocker locker(&m_mutex);
    m_logLevel = level;
}

void Logger::debug(const QString& module, const QString& message) {
    if (m_logLevel <= DEBUG) {
        writeLog(DEBUG, module, message);
    }
}

void Logger::info(const QString& module, const QString& message) {
    if (m_logLevel <= INFO) {
        writeLog(INFO, module, message);
    }
}

void Logger::warning(const QString& module, const QString& message) {
    if (m_logLevel <= WARNING) {
        writeLog(WARNING, module, message);
    }
}

void Logger::error(const QString& module, const QString& message) {
    if (m_logLevel <= ERROR) {
        writeLog(ERROR, module, message);
    }
}

void Logger::critical(const QString& module, const QString& message) {
    if (m_logLevel <= CRITICAL) {
        writeLog(CRITICAL, module, message);
    }
}

void Logger::writeLog(LogLevel level, const QString& module, const QString& message) {
    QMutexLocker locker(&m_mutex);
    
    QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz");
    QString levelStr = levelToString(level);
    QString color = levelToColor(level);
    QString logLine = QString("[%1] [%2] [%3] %4\n")
                      .arg(timestamp)
                      .arg(levelStr)
                      .arg(module)
                      .arg(message);
    
    if (m_logFile.isOpen()) {
        QTextStream stream(&m_logFile);
        stream << logLine;
        stream.flush();
    } else {
        std::cerr << logLine.toStdString();
    }
    
    QVariantMap logEntry;
    logEntry["timestamp"] = timestamp;
    logEntry["level"] = levelStr;
    logEntry["module"] = module;
    logEntry["message"] = message;
    logEntry["color"] = color;
    m_logHistory.append(logEntry);
    
    if (m_logHistory.size() > 100) {
        m_logHistory.removeFirst();
    }
    
    qDebug() << "[DEBUG Logger] Emitting logAdded - level:" << levelStr << "module:" << module << "message:" << message;
    emit logAdded(timestamp, levelStr, module, message, color);
}

QList<QVariantMap> Logger::getLogHistory() const {
    QMutexLocker locker(const_cast<QMutex*>(&m_mutex));
    return m_logHistory;
}

QString Logger::levelToString(LogLevel level) {
    switch (level) {
    case DEBUG:
        return "DEBUG";
    case INFO:
        return "INFO";
    case WARNING:
        return "WARNING";
    case ERROR:
        return "ERROR";
    case CRITICAL:
        return "CRITICAL";
    default:
        return "UNKNOWN";
    }
}

QString Logger::levelToColor(LogLevel level) {
    switch (level) {
    case DEBUG:
        return "#888888";
    case INFO:
        return "#00FF00";
    case WARNING:
        return "#FFFF00";
    case ERROR:
        return "#FF0000";
    case CRITICAL:
        return "#8B0000";
    default:
        return "#FFFFFF";
    }
}