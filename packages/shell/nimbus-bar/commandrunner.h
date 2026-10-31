#pragma once
// CommandRunner mínimo (F3-T04): ejecuta comandos sin Quickshell.
#include <QObject>
#include <QProcess>
#include <QDebug>
#include <QString>

class CommandRunner : public QObject {
    Q_OBJECT
public:
    explicit CommandRunner(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE void run(const QString &cmd) {
        QStringList parts = QProcess::splitCommand(cmd);
        if (parts.isEmpty())
            return;
        QString prog = parts.takeFirst();
        QProcess::startDetached(prog, parts);
        emit finished(cmd, 0);
    }
    // Log sin ejecución (diagnóstico --log-actions, stderr sin buffer).
    Q_INVOKABLE void logAction(int i, const QString &cmd) {
        qInfo().noquote() << QStringLiteral("MENU_ACTION %1 %2")
                                 .arg(i)
                                 .arg(cmd.isEmpty() ? QStringLiteral("-") : cmd);
    }
signals:
    void finished(const QString &cmd, int code);
};
