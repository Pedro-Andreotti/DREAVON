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
QJsonArray claudeSessionMessages(const QString &path, QString *cwd = nullptr, QString *error = nullptr);

// Sessões locais do Antigravity (~/.gemini/antigravity-cli/brain/<id> e ~/.gemini/antigravity/brain/<id>).
QStringList antigravityConfigDirs();
QStringList antigravitySessionFiles();
QString findAntigravitySession(const QString &id, bool *resumable = nullptr);
QVariantMap antigravitySessionSummary(const QString &path, const QString &pragusWorkspace);
QJsonArray antigravitySessionMessages(const QString &path, QString *cwd = nullptr, QString *error = nullptr);

// Sessões locais do Codex (~/.codex/sessions/.../*.jsonl).
QString codexConfigDir();
QStringList codexSessionFiles();
QString findCodexSession(const QString &id);
QVariantMap codexSessionSummary(const QString &path, const QString &pragusWorkspace);
QJsonArray codexSessionMessages(const QString &path, QString *cwd = nullptr, QString *error = nullptr);
}
