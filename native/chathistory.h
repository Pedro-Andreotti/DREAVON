#pragma once

#include <QJsonArray>
#include <QStringList>
#include <QJsonObject>
#include <QUrl>
#include <QVariantMap>

namespace ChatHistory {
QVariantMap summary(const QJsonObject &thread, const QString &pragusWorkspace);
QJsonArray messagesFromTurns(const QJsonArray &turns);
QJsonArray importMessages(const QUrl &url, QString *error);
QString transcript(const QJsonArray &messages);
QString contextInput(const QJsonArray &messages);

// Sessões locais do Claude Code (~/.claude/projects/<projeto>/<sessão>.jsonl).
QString claudeConfigDir();
QStringList claudeSessionFiles();
QString findClaudeSession(const QString &id);
// Mapa vazio quando o arquivo não é uma conversa que possa ser retomada aqui.
QVariantMap claudeSessionSummary(const QString &path, const QString &pragusWorkspace);
QJsonArray claudeSessionMessages(const QString &path, QString *cwd, QString *error);
}
