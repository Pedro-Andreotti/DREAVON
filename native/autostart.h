#pragma once

#include <QObject>

// "Iniciar com o Windows": o valor "DREAVON" na chave Run do usuário (HKCU), sem serviço nem tarefa
// agendada. O comando é o mesmo que abriu o app agora (qml.exe do Qt + windows/dreavon.qml), mais
// "-- --bandeja" para abrir só na bandeja. Também pode ser ligado e desligado por
// tools/install-local.ps1. Fora do Windows, supported = false e a opção fica oculta.
class Autostart : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool supported READ supported CONSTANT)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY changed)
public:
    explicit Autostart(QObject *parent = nullptr);
    bool supported() const;
    bool enabled() const;
    void setEnabled(bool on);

signals:
    void changed();

private:
    QString command() const;
};
