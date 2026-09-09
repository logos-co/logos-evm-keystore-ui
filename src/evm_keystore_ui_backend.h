#pragma once

#include <QJsonObject>
#include <QObject>
#include <QString>

#include "rep_evm_keystore_ui_source.h"
#include "logos_ui_plugin_context.h"

// The keystore UI backend.
//
// Every keystore call is made here over the generated typed client; the QML half renders and
// collects passwords. This module is the configured CUSTODIAN — the one caller the keystore's
// Tier D admits — which is why the mutating calls below exist here and nowhere else.
//
// Secrets are returned from methods, never published as properties: a property is cached in
// the shell process and broadcast to every connected replica.
class EvmKeystoreUiBackend : public EvmKeystoreUiSimpleSource,
                             public LogosUiPluginContext
{
public:
    void refresh() override;

    QString generateMnemonic(int words) override;
    bool importMnemonic(QString phrase, QString bip39Passphrase, QString accountPassword,
                        QString groupPassword, bool derivable, QString groupLabel) override;
    bool importPrivateKey(QString privHex, QString accountPassword) override;
    bool importVaultJson(QString vaultJson, QString oldPassword, QString newPassword) override;

    bool deriveNextAccount(QString group, QString groupPassword, QString accountPassword) override;
    bool deriveAccountAt(QString group, QString groupPassword, QString accountPassword,
                         int bip44Account, int change, int index) override;
    QString previewAddresses(QString group, QString groupPassword, int change, int from,
                             int count) override;
    bool forgetDerivation(QString group) override;
    bool removeWallet(QString group) override;

    QString exportVaultJson(QString address, QString password) override;

    bool setLabel(QString address, QString label, QString password) override;
    bool setWalletName(QString group, QString name, QString address, QString password) override;
    bool changePassword(QString address, QString oldPassword, QString newPassword) override;
    bool deleteAccount(QString address, QString password) override;

protected:
    void onContextReady() override;

private:
    /// Append one message to what is on screen. NEVER overwritten: one refresh makes six
    /// reads, and an overwrite left only the last refusal showing.
    void say(const QString &line);
    /// Surface a keystore refusal verbatim and report whether the call succeeded. The rule
    /// that produced the message lives in the keystore; restating it here would be a copy
    /// free to drift from the one that actually governs.
    bool ok(const QString &reply, const QString &context);
    /// `ok`, and record whether that read answered under `key`. A refused read empties what
    /// it feeds; the view cannot tell that from an empty keystore unless it is told.
    bool read(const QString &key, const QString &reply, const QString &context);
    void publishReads();
    void loadAccounts();
    void loadGroups();
    void loadIdentity();

    QJsonObject m_reads;
};
