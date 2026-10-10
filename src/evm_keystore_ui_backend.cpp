#include "evm_keystore_ui_backend.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

// The generated umbrella carrying `struct LogosModules`.
#include "logos_sdk.h"

namespace {

QJsonObject parseObject(const QString &reply)
{
    return QJsonDocument::fromJson(reply.toUtf8()).object();
}

QString compact(const QJsonValue &v)
{
    if (v.isArray())
        return QString::fromUtf8(QJsonDocument(v.toArray()).toJson(QJsonDocument::Compact));
    if (v.isObject())
        return QString::fromUtf8(QJsonDocument(v.toObject()).toJson(QJsonDocument::Compact));
    return {};
}

QString params(const QJsonObject &o)
{
    return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

} // namespace

void EvmKeystoreUiBackend::say(const QString &line)
{
    setLastError(lastError().isEmpty() ? line : lastError() + QLatin1Char('\n') + line);
}

bool EvmKeystoreUiBackend::ok(const QString &reply, const QString &context)
{
    const QJsonObject o = parseObject(reply);
    if (o.value(QStringLiteral("ok")).toBool())
        return true;
    QString e = o.value(QStringLiteral("error")).toString();
    if (e.isEmpty())
        e = QStringLiteral("the keystore refused the request");
    // "not authorized" is what a non-custodian gets. Say what that means rather than
    // repeating a string that reads like a bug.
    if (e == QLatin1String("not authorized"))
        e = QStringLiteral("this build is not the keystore's configured custodian, so it may "
                           "not change accounts");
    say(context.isEmpty() ? e : QStringLiteral("%1: %2").arg(context, e));
    return false;
}

bool EvmKeystoreUiBackend::okManager(const QString &reply, const QString &context)
{
    const QJsonObject o = parseObject(reply);
    if (o.value(QStringLiteral("ok")).toBool())
        return true;
    QString e = o.value(QStringLiteral("error")).toString();
    if (e.isEmpty())
        e = QStringLiteral("the signer manager refused the request");
    if (e == QLatin1String("not authorized"))
        e = QStringLiteral("this build is not the signer manager's configured custodian, so it may "
                           "not open or unlock accounts for apps");
    say(context.isEmpty() ? e : QStringLiteral("%1: %2").arg(context, e));
    return false;
}

bool EvmKeystoreUiBackend::read(const QString &key, const QString &reply, const QString &context)
{
    const bool good = ok(reply, context);
    m_reads[key] = good;
    return good;
}

void EvmKeystoreUiBackend::publishReads()
{
    setReadsJson(QString::fromUtf8(QJsonDocument(m_reads).toJson(QJsonDocument::Compact)));
}

void EvmKeystoreUiBackend::onContextReady()
{
    // The account list changes under us when this UI is not the only thing running.
    modules().keystore_module.onAccounts_changed([this](int) {
        QTimer::singleShot(0, [this] { refresh(); });
    });
    // Requests from apps, and unlocks ending or changing. Handles only; re-read off the IPC stack.
    modules().signer_manager_module.onAccess_requested([this](QString) {
        QTimer::singleShot(0, this, [this] { refreshAccess(); });
    });
    modules().signer_manager_module.onAccess_settled([this](QString, QString) {
        QTimer::singleShot(0, this, [this] { refreshAccess(); });
    });
    modules().signer_manager_module.onUnlock_changed([this](QString) {
        QTimer::singleShot(0, this, [this] { refreshAccess(); });
    });
    refresh();
}

void EvmKeystoreUiBackend::loadPhrases()
{
    const QString reply = modules().keystore_module.list_phrases();
    setPhrasesJson(read(QStringLiteral("phrases"), reply, QStringLiteral("kept phrases"))
                       ? compact(parseObject(reply).value(QStringLiteral("phrases")))
                       : QStringLiteral("[]"));
    publishReads();
}

QString EvmKeystoreUiBackend::importBitcoinWith(QJsonObject p)
{
    setLastError(QString());
    QString body = params(p);
    for (const QString &k : { QStringLiteral("phrase"), QStringLiteral("passphrase"), QStringLiteral("password"),
                              QStringLiteral("phrasePassword") })
        p.remove(k);
    const QString reply = modules().keystore_module.import_bitcoin(body);
    body.fill(QChar(0));
    if (!ok(reply, QStringLiteral("Bitcoin wallet")))
        return QString();
    refresh();
    return parseObject(reply).value(QStringLiteral("group")).toString();
}

QString EvmKeystoreUiBackend::importBitcoin(QString phrase, QString bip39Passphrase, QString family, QString chain,
                                            QString password, QString label, QString keepPhrasePassword)
{
    QJsonObject p;
    p[QStringLiteral("phrase")] = phrase;
    p[QStringLiteral("passphrase")] = bip39Passphrase;
    p[QStringLiteral("family")] = family;
    p[QStringLiteral("chain")] = chain;
    p[QStringLiteral("password")] = password;
    p[QStringLiteral("label")] = label;
    if (!keepPhrasePassword.isEmpty())
        p[QStringLiteral("keepPhrase")] = QJsonObject{ { QStringLiteral("password"), keepPhrasePassword } };
    phrase.fill(QChar(0));
    bip39Passphrase.fill(QChar(0));
    password.fill(QChar(0));
    keepPhrasePassword.fill(QChar(0));
    return importBitcoinWith(p);
}

QString EvmKeystoreUiBackend::importBitcoinFromKept(QString phraseId, QString phrasePassword, QString bip39Passphrase,
                                                    QString family, QString chain, QString password, QString label)
{
    QJsonObject p;
    p[QStringLiteral("keptPhrase")] = phraseId;
    p[QStringLiteral("phrasePassword")] = phrasePassword;
    p[QStringLiteral("passphrase")] = bip39Passphrase;
    p[QStringLiteral("family")] = family;
    p[QStringLiteral("chain")] = chain;
    p[QStringLiteral("password")] = password;
    p[QStringLiteral("label")] = label;
    phrasePassword.fill(QChar(0));
    bip39Passphrase.fill(QChar(0));
    password.fill(QChar(0));
    return importBitcoinWith(p);
}

QString EvmKeystoreUiBackend::showPhrase(QString phraseId, QString password)
{
    setLastError(QString());
    QJsonObject p;
    p[QStringLiteral("phrase")] = phraseId;
    p[QStringLiteral("password")] = password;
    QString body = params(p);
    password.fill(QChar(0));
    const QString reply = modules().keystore_module.show_phrase(body);
    body.fill(QChar(0));
    if (!ok(reply, QStringLiteral("show phrase")))
        return {};
    return parseObject(reply).value(QStringLiteral("words")).toString();
}

bool EvmKeystoreUiBackend::forgetPhrase(QString phraseId)
{
    setLastError(QString());
    QJsonObject p;
    p[QStringLiteral("phrase")] = phraseId;
    const bool good = ok(modules().keystore_module.forget_phrase(params(p)), QStringLiteral("forget phrase"));
    refresh();
    return good;
}

QString EvmKeystoreUiBackend::walletDescriptors(QString group)
{
    setLastError(QString());
    QJsonObject p;
    p[QStringLiteral("group")] = group;
    const QString reply = modules().keystore_module.account_descriptors(params(p));
    if (!ok(reply, QStringLiteral("descriptor")))
        return {};
    QJsonObject o = parseObject(reply);
    o.remove(QStringLiteral("ok"));
    return compact(o);
}

void EvmKeystoreUiBackend::refreshAccess()
{
    const QJsonObject id = parseObject(modules().signer_manager_module.caller_identity());
    const QString me = id.value(QStringLiteral("identity")).toString();
    const bool custodian = !me.isEmpty()
        && id.value(QStringLiteral("custodians")).toArray().contains(QJsonValue(me));
    setIsManagerCustodian(custodian);
    if (!custodian) {
        setAccessJson(QStringLiteral("[]"));
        setUnlockedJson(QStringLiteral("[]"));
        setOpenJson(QStringLiteral("[]"));
        return;
    }
    const QJsonObject q = parseObject(modules().signer_manager_module.access_requests());
    setAccessJson(compact(q.value(QStringLiteral("requests")).toArray()));
    const QJsonObject u = parseObject(modules().signer_manager_module.unlocked());
    setUnlockedJson(compact(u.value(QStringLiteral("unlocked")).toArray()));
    const QJsonObject o = parseObject(modules().signer_manager_module.open_accounts());
    setOpenJson(compact(o.value(QStringLiteral("open")).toArray()));
    // A request that settled elsewhere leaves the screen with it.
    const QString shown = parseObject(accessShownJson()).value(QStringLiteral("handle")).toString();
    if (!shown.isEmpty()) {
        bool still = false;
        for (const QJsonValue &r : q.value(QStringLiteral("requests")).toArray())
            still = still || r.toObject().value(QStringLiteral("handle")).toString() == shown;
        if (!still)
            setAccessShownJson(QStringLiteral("{}"));
    }
}

bool EvmKeystoreUiBackend::showAccess(QString handle)
{
    setLastError(QString());
    const QString reply = modules().signer_manager_module.acknowledge_access(handle);
    if (!okManager(reply, QStringLiteral("open the request"))) {
        setAccessShownJson(QStringLiteral("{}"));
        return false;
    }
    QJsonObject shown = parseObject(reply);
    shown.remove(QStringLiteral("ok"));
    setAccessShownJson(compact(shown));
    return true;
}

bool EvmKeystoreUiBackend::approveAccess(QString handle, QString bundleId, QString group,
                                         QString password, QString unlockJson)
{
    setLastError(QString());
    // Only what is on screen, and refused before the password is used for anything else.
    const QJsonObject shown = parseObject(accessShownJson());
    if (handle.isEmpty() || shown.value(QStringLiteral("handle")).toString() != handle
        || shown.value(QStringLiteral("bundle_id")).toString() != bundleId) {
        say(QStringLiteral("That is not the request on screen."));
        password.fill(QChar(0));
        return false;
    }
    QJsonObject p;
    p[QStringLiteral("handle")] = handle;
    p[QStringLiteral("bundle_id")] = bundleId;
    p[QStringLiteral("password")] = password;
    if (!group.isEmpty())
        p[QStringLiteral("group")] = group;
    const QJsonObject terms = QJsonDocument::fromJson(unlockJson.toUtf8()).object();
    if (!terms.isEmpty())
        p[QStringLiteral("unlock")] = terms;
    QString body = params(p);
    password.fill(QChar(0));
    const bool good = okManager(modules().signer_manager_module.approve_access(body), QString());
    body.fill(QChar(0));
    if (good) {
        setAccessShownJson(QStringLiteral("{}"));
        setStatusText(QStringLiteral("Done for %1").arg(shown.value(QStringLiteral("requester")).toString()));
    }
    refreshAccess();
    return good;
}

bool EvmKeystoreUiBackend::rejectAccess(QString handle)
{
    setLastError(QString());
    const bool good = modules().signer_manager_module.reject_access(handle);
    if (good)
        setAccessShownJson(QStringLiteral("{}"));
    refreshAccess();
    return good;
}

void EvmKeystoreUiBackend::dismissAccess()
{
    setAccessShownJson(QStringLiteral("{}"));
}

bool EvmKeystoreUiBackend::unlockAccount(QString account, QString password, QString termsJson)
{
    setLastError(QString());
    QJsonObject p = QJsonDocument::fromJson(termsJson.toUtf8()).object();
    p[QStringLiteral("account")] = account;
    p[QStringLiteral("password")] = password;
    QString body = params(p);
    password.fill(QChar(0));
    const bool good = okManager(modules().signer_manager_module.unlock(body), QStringLiteral("unlock"));
    body.fill(QChar(0));
    refreshAccess();
    return good;
}

bool EvmKeystoreUiBackend::lockAccount(QString account)
{
    setLastError(QString());
    QJsonObject p;
    if (!account.isEmpty())
        p[QStringLiteral("account")] = account;
    const bool good = okManager(modules().signer_manager_module.lock(params(p)), QStringLiteral("lock"));
    refreshAccess();
    return good;
}

bool EvmKeystoreUiBackend::closeWallet(QString module, QString group)
{
    setLastError(QString());
    QJsonObject p;
    p[QStringLiteral("group")] = group;
    p[QStringLiteral("module")] = module;
    const bool good =
        okManager(modules().signer_manager_module.close_account(params(p)), QStringLiteral("close"));
    refreshAccess();
    return good;
}

void EvmKeystoreUiBackend::loadIdentity()
{
    const QString reply = modules().keystore_module.caller_identity();
    const QJsonObject o = parseObject(reply);
    setIdentityJson(QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact)));

    // Say plainly whether we hold the role, instead of letting every mutation fail
    // mysteriously one screen later.
    const QString me = o.value(QStringLiteral("identity")).toString();
    const QJsonArray custodians = o.value(QStringLiteral("custodians")).toArray();
    setIsCustodian(!me.isEmpty() && custodians.contains(QJsonValue(me)));
}

void EvmKeystoreUiBackend::loadAccounts()
{
    // A refused read clears what it feeds, like the wallet reads below. The listing can now
    // fail — an unreadable keystore directory refuses instead of answering "no accounts" —
    // and leaving the previous list on screen would show accounts with a confidence the
    // keystore has just withdrawn, next to an error saying it could not read them.
    const QString accounts = modules().keystore_module.list_accounts();
    setAccountsJson(read(QStringLiteral("accounts"), accounts, QStringLiteral("accounts"))
                        ? compact(parseObject(accounts).value(QStringLiteral("accounts")))
                        : QStringLiteral("[]"));

    const QString labels = modules().keystore_module.get_labels();
    setLabelsJson(read(QStringLiteral("labels"), labels, QStringLiteral("labels"))
                      ? compact(parseObject(labels).value(QStringLiteral("labels")))
                      : QStringLiteral("{}"));
    publishReads();
}

void EvmKeystoreUiBackend::loadGroups()
{
    // A refused read clears what it feeds. Leaving the previous answer on screen would say
    // "no wallets" or "these wallets" with the same confidence the keystore just withdrew.
    const QString groups = modules().keystore_module.list_groups();
    setGroupsJson(read(QStringLiteral("groups"), groups, QStringLiteral("wallets"))
                      ? compact(parseObject(groups).value(QStringLiteral("groups")))
                      : QStringLiteral("[]"));

    const QString provenance = modules().keystore_module.get_provenance();
    setProvenanceJson(read(QStringLiteral("provenance"), provenance, QStringLiteral("provenance"))
                          ? compact(parseObject(provenance).value(QStringLiteral("accounts")))
                          : QStringLiteral("{}"));

    // Its own document, so a wallet whose record is gone keeps its name — and an unreadable
    // one refuses here rather than answering that nothing is named.
    const QString names = modules().keystore_module.get_group_labels();
    setWalletNamesJson(read(QStringLiteral("walletNames"), names, QStringLiteral("wallet names"))
                           ? compact(parseObject(names).value(QStringLiteral("labels")))
                           : QStringLiteral("{}"));

    // Read from the key directory alone, so it survives an unreadable groups.json. Without
    // it a whole-wallet key whose record is gone could not be named, and so never deleted.
    // The whole reply is carried: `staged` and `unexplained` are the states that refuse a
    // new account, and a refusal the user cannot see the reason for is a wedge.
    const QString keys = modules().keystore_module.list_derivation_keys();
    QJsonObject dir;
    if (read(QStringLiteral("derivationKeys"), keys, QStringLiteral("derivation keys"))) {
        const QJsonObject r = parseObject(keys);
        for (const QString &k : { QStringLiteral("groups"), QStringLiteral("staged"),
                                  QStringLiteral("unexplained") })
            dir[k] = r.value(k).toArray();
    }
    setKeyDirectoryJson(compact(dir));
    publishReads();
}

void EvmKeystoreUiBackend::refresh()
{
    setBusy(true);
    setLastError(QString());
    loadIdentity();
    loadAccounts();
    loadGroups();
    loadPhrases();
    refreshAccess();
    setStatusText(isCustodian() ? QStringLiteral("Ready")
                                : QStringLiteral("Not the configured custodian"));
    setBusy(false);
}

QString EvmKeystoreUiBackend::generateMnemonic(int words)
{
    setLastError(QString());
    const QString reply = modules().keystore_module.create_mnemonic(words);
    if (!ok(reply, QStringLiteral("generate")))
        return {};
    return parseObject(reply).value(QStringLiteral("phrase")).toString();
}

bool EvmKeystoreUiBackend::importMnemonic(QString phrase, QString bip39Passphrase,
                                          QString accountPassword, QString groupPassword,
                                          bool derivable, QString groupLabel)
{
    setLastError(QString());
    QJsonObject p;
    p[QStringLiteral("phrase")] = phrase;
    p[QStringLiteral("passphrase")] = bip39Passphrase;
    p[QStringLiteral("password")] = accountPassword;
    // The wallet's name, kept whichever storage is chosen: a group record is written for both,
    // and this is the only moment the keystore accepts one.
    p[QStringLiteral("groupLabel")] = groupLabel;
    // An import always creates the wallet's FIRST account; further ones come from
    // deriveNextAccount, which is the only thing that knows which indices are taken.
    p[QStringLiteral("storage")] = derivable ? QStringLiteral("extkey") : QStringLiteral("plain");
    if (derivable)
        p[QStringLiteral("groupPassword")] = groupPassword;
    const bool good = ok(modules().keystore_module.import_mnemonic(params(p)), QString());
    if (good)
        refresh();
    return good;
}

bool EvmKeystoreUiBackend::importPrivateKey(QString privHex, QString accountPassword)
{
    setLastError(QString());
    const bool good =
        ok(modules().keystore_module.import_private_key(privHex, accountPassword), QString());
    if (good)
        refresh();
    return good;
}

bool EvmKeystoreUiBackend::importVaultJson(QString vaultJson, QString oldPassword, QString newPassword)
{
    setLastError(QString());
    const bool good = ok(
        modules().keystore_module.import_keystore_json(vaultJson, oldPassword, newPassword),
        QString());
    if (good)
        refresh();
    return good;
}

bool EvmKeystoreUiBackend::deriveNextAccount(QString group, QString groupPassword,
                                             QString accountPassword)
{
    setLastError(QString());
    QJsonObject p;
    // Omitted, not empty: the keystore reads an absent group as "the only one that can
    // derive", and refuses by name when several can.
    if (!group.isEmpty())
        p[QStringLiteral("group")] = group;
    p[QStringLiteral("groupPassword")] = groupPassword;
    p[QStringLiteral("password")] = accountPassword;
    const bool good = ok(modules().keystore_module.derive_next_account(params(p)), QString());
    if (good)
        refresh();
    return good;
}

bool EvmKeystoreUiBackend::deriveAccountAt(QString group, QString groupPassword,
                                           QString accountPassword, int bip44Account, int change,
                                           int index)
{
    setLastError(QString());
    // The keystore's path levels are unsigned; a negative would come back as an opaque
    // parse failure instead of something the person typing it can act on.
    if (bip44Account < 0 || change < 0 || index < 0) {
        say(QStringLiteral("account, change and index must not be negative"));
        return false;
    }
    QJsonObject p;
    p[QStringLiteral("group")] = group;
    p[QStringLiteral("groupPassword")] = groupPassword;
    p[QStringLiteral("password")] = accountPassword;
    p[QStringLiteral("bip44Account")] = bip44Account;
    p[QStringLiteral("change")] = change;
    p[QStringLiteral("index")] = index;
    const bool good = ok(modules().keystore_module.derive_account_at(params(p)), QString());
    if (good)
        refresh();
    return good;
}

QString EvmKeystoreUiBackend::previewAddresses(QString group, QString groupPassword, int change,
                                               int from, int count)
{
    setLastError(QString());
    if (change < 0 || from < 0 || count < 0) {
        say(QStringLiteral("change, start and count must not be negative"));
        return {};
    }
    QJsonObject p;
    p[QStringLiteral("group")] = group;
    p[QStringLiteral("groupPassword")] = groupPassword;
    p[QStringLiteral("change")] = change;
    p[QStringLiteral("from")] = from;
    p[QStringLiteral("count")] = count;
    const QString reply = modules().keystore_module.preview_addresses(params(p));
    if (!ok(reply, QStringLiteral("preview")))
        return {};
    return compact(parseObject(reply).value(QStringLiteral("addresses")));
}

bool EvmKeystoreUiBackend::forgetDerivation(QString group)
{
    setLastError(QString());
    QJsonObject p;
    p[QStringLiteral("group")] = group;
    const QString reply = modules().keystore_module.forget_derivation(params(p));
    const bool good = ok(reply, QStringLiteral("stop keeping the derivation key"));
    if (good)
        refresh();
    // The key is gone either way. A stranded key had no record to update; anything else
    // means groups.json is unreadable, and the wallet may still read as derivable. Appended,
    // because refresh() above may have just recorded refusals of its own.
    const QJsonObject r = parseObject(reply);
    if (good && !r.value(QStringLiteral("recordUpdated")).toBool()
        && !r.value(QStringLiteral("stranded")).toBool())
        say(QStringLiteral("the derivation key is deleted, but this wallet's record could not "
                           "be updated — it may still read as derivable"));
    return good;
}

bool EvmKeystoreUiBackend::removeWallet(QString group)
{
    setLastError(QString());
    QJsonObject p;
    p[QStringLiteral("group")] = group;
    const QString reply = modules().keystore_module.remove_group(params(p));
    const QJsonObject r = parseObject(reply);
    // Already gone is not a refusal to report: another surface removed it, and the row this
    // was pressed on is stale. Match on the tail — the keystore prefixes the variant.
    if (!r.value(QStringLiteral("ok")).toBool()
        && r.value(QStringLiteral("error")).toString().contains(QLatin1String("no such group"))) {
        refresh();
        return true;
    }
    const bool good = ok(reply, QStringLiteral("remove wallet"));
    if (good)
        refresh();
    return good;
}

QString EvmKeystoreUiBackend::exportVaultJson(QString address, QString password)
{
    setLastError(QString());
    const QString reply = modules().keystore_module.export_keystore_json(address, password);
    if (!ok(reply, QStringLiteral("export")))
        return {};
    return parseObject(reply).value(QStringLiteral("keystore")).toString();
}

bool EvmKeystoreUiBackend::setLabel(QString address, QString label, QString password)
{
    setLastError(QString());
    // The keystore decides which of the two this is; it ignores the password when the label
    // is blank, and no KDF runs. Passing it either way keeps that rule in one place.
    const bool good = ok(modules().keystore_module.set_label(address, label, password),
                         QStringLiteral("rename"));
    if (good)
        loadAccounts();
    return good;
}

bool EvmKeystoreUiBackend::setWalletName(QString group, QString name, QString address,
                                         QString password)
{
    setLastError(QString());
    QJsonObject p;
    p[QStringLiteral("group")] = group;
    p[QStringLiteral("label")] = name;
    // Omitted rather than empty: a present address is what tells the keystore an ACCOUNT is
    // being offered, so sending a blank one would turn a wallet with none into a failed
    // lookup. The password travels on its own, because a wallet with no accounts and a key
    // on disk is proved against that key instead.
    if (!address.isEmpty())
        p[QStringLiteral("address")] = address;
    if (!password.isEmpty())
        p[QStringLiteral("password")] = password;
    const bool good = ok(modules().keystore_module.set_group_label(params(p)),
                         QStringLiteral("rename wallet"));
    if (good)
        loadGroups();
    return good;
}

bool EvmKeystoreUiBackend::changePassword(QString address, QString oldPassword, QString newPassword)
{
    setLastError(QString());
    return ok(modules().keystore_module.change_password(address, oldPassword, newPassword),
              QStringLiteral("change password"));
}

bool EvmKeystoreUiBackend::deleteAccount(QString address, QString password)
{
    setLastError(QString());
    // delete_account answers a bare bool: a refusal and a wrong password are indistinguishable
    // there by construction, so there is no message to surface beyond this.
    const bool good = modules().keystore_module.delete_account(address, password);
    if (good)
        refresh();
    else
        say(QStringLiteral("could not delete the account — wrong password, or this build is "
                           "not the configured custodian"));
    return good;
}
