// tst_index — unit tests del índice local Nimbus (F6-T02).
// fuzzy, calculadora (precedencia/errores), parser .desktop, perf 10k.
#include <QClipboard>
#include <QElapsedTimer>
#include <QGuiApplication>
#include <QTemporaryDir>
#include <QTemporaryFile>
#include <QtTest>

#include "../nimbusindex.h"

class TstIndex : public QObject {
    Q_OBJECT
private Q_SLOTS:
    void fuzzyRanking()
    {
        const int exact = NimbusIndex::fuzzyScore(QStringLiteral("kate"), QStringLiteral("kate"));
        const int prefix = NimbusIndex::fuzzyScore(QStringLiteral("kate"), QStringLiteral("kat"));
        const int sub = NimbusIndex::fuzzyScore(QStringLiteral("la kate x"), QStringLiteral("kate"));
        const int fuzzy = NimbusIndex::fuzzyScore(QStringLiteral("kate"), QStringLiteral("kte"));
        const int none = NimbusIndex::fuzzyScore(QStringLiteral("dolphin"), QStringLiteral("kate"));
        QVERIFY(exact >= 0 && prefix >= 0 && sub >= 0 && fuzzy >= 0);
        QVERIFY(exact < prefix && prefix < sub && sub < fuzzy);
        QCOMPARE(none, -1);
        QCOMPARE(NimbusIndex::fuzzyScore(QStringLiteral("Kate"), QStringLiteral("KATE")), 0);
    }

    void calcPrecedence()
    {
        bool ok = false;
        QCOMPARE(NimbusIndex::evalCalc(QStringLiteral("2+2"), ok), 4.0);
        QVERIFY(ok);
        QCOMPARE(NimbusIndex::evalCalc(QStringLiteral("2+3*4"), ok), 14.0);
        QVERIFY(ok);
        QCOMPARE(NimbusIndex::evalCalc(QStringLiteral("(2+3)*4"), ok), 20.0);
        QVERIFY(ok);
        QCOMPARE(NimbusIndex::evalCalc(QStringLiteral("2^3"), ok), 8.0);
        QVERIFY(ok);
        QCOMPARE(NimbusIndex::evalCalc(QStringLiteral("10%3"), ok), 1.0);
        QVERIFY(ok);
        QCOMPARE(NimbusIndex::evalCalc(QStringLiteral("7/2"), ok), 3.5);
        QVERIFY(ok);
        QCOMPARE(NimbusIndex::evalCalc(QStringLiteral("-3+2*2"), ok), 1.0);
        QVERIFY(ok);
        QCOMPARE(NimbusIndex::evalCalc(QStringLiteral("2.5*2"), ok), 5.0);
        QVERIFY(ok);
    }

    void calcErrors()
    {
        bool ok = true;
        NimbusIndex::evalCalc(QStringLiteral("1/0"), ok);
        QVERIFY(!ok);
        NimbusIndex::evalCalc(QStringLiteral("2++2"), ok);
        QVERIFY(!ok);
        NimbusIndex::evalCalc(QStringLiteral("(2+3"), ok);
        QVERIFY(!ok);
        NimbusIndex::evalCalc(QStringLiteral("2+"), ok);
        QVERIFY(!ok);
        NimbusIndex::evalCalc(QStringLiteral("hola"), ok);
        QVERIFY(!ok);
        QVERIFY(!NimbusIndex::isCalcQuery(QStringLiteral("kate")));
        QVERIFY(!NimbusIndex::isCalcQuery(QStringLiteral("hola mundo")));
        QVERIFY(NimbusIndex::isCalcQuery(QStringLiteral("2+2")));
        QVERIFY(NimbusIndex::isCalcQuery(QStringLiteral("(3+4) * 2")));
    }

    void desktopParser()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString good = dir.filePath(QStringLiteral("kate.desktop"));
        QFile f(good);
        QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Text));
        f.write("[Desktop Entry]\nType=Application\nName=Kate\n"
                "Exec=kate %U\nIcon=kate\nCategories=Utility;TextEditor;\n"
                "Keywords=editor;texto;\n");
        f.close();
        LocalApp a;
        QVERIFY(NimbusIndex::parseDesktopFile(good, a));
        QCOMPARE(a.name, QStringLiteral("Kate"));
        QCOMPARE(a.exec, QStringLiteral("kate")); // %U limpio
        QCOMPARE(a.iconName, QStringLiteral("kate"));

        const QString hidden = dir.filePath(QStringLiteral("x.desktop"));
        QFile fh(hidden);
        QVERIFY(fh.open(QIODevice::WriteOnly | QIODevice::Text));
        fh.write("[Desktop Entry]\nType=Application\nName=X\nExec=x\nNoDisplay=true\n");
        fh.close();
        LocalApp b;
        QVERIFY(!NimbusIndex::parseDesktopFile(hidden, b));

        const QString noexec = dir.filePath(QStringLiteral("y.desktop"));
        QFile fy(noexec);
        QVERIFY(fy.open(QIODevice::WriteOnly | QIODevice::Text));
        fy.write("[Desktop Entry]\nType=Application\nName=Y\n");
        fy.close();
        LocalApp c;
        QVERIFY(!NimbusIndex::parseDesktopFile(noexec, c));
    }

    void webUrlNoNet()
    {
        QCOMPARE(NimbusIndex::webUrl(QStringLiteral("?hola mundo")),
                 QStringLiteral("https://duckduckgo.com/?q=hola%20mundo"));
        QVERIFY(NimbusIndex::webUrl(QStringLiteral("kate")).startsWith(
            QStringLiteral("https://duckduckgo.com/?q=")));
    }

    void perfFuzzy10k()
    {
        // 10k candidatos sintéticos: el match en índice construido debe ser <50ms.
        QStringList names;
        for (int i = 0; i < 10000; ++i)
            names << QStringLiteral("documento-informe-%1-final.odt").arg(i);
        names[4242] = QStringLiteral("kate-notas.txt");
        QElapsedTimer t;
        t.start();
        int hits = 0;
        for (const QString &n : names)
            if (NimbusIndex::fuzzyScore(n, QStringLiteral("kate")) >= 0)
                ++hits;
        const qint64 ms = t.elapsed();
        QVERIFY(hits >= 1);
        qInfo("perf-fuzzy-10k: %lldms hits=%d", ms, hits);
        QVERIFY2(ms < 50, qPrintable(QStringLiteral("fuzzy 10k tardó %1ms").arg(ms)));
    }

    void perfSearchLocal()
    {
        NimbusIndex idx;
        QElapsedTimer t;
        t.start();
        idx.searchLocal(QStringLiteral("kate"), QStringLiteral("apps"));
        const qint64 ms = t.elapsed();
        qInfo("perf-searchLocal: %lldms results=%d", ms, idx.localMatches().size());
        QVERIFY2(ms < 50, qPrintable(QStringLiteral("searchLocal tardó %1ms").arg(ms)));
        // Calculadora responde inline sin índice.
        idx.searchLocal(QStringLiteral("2+2"), QStringLiteral("actions"));
        QVERIFY(!idx.localMatches().isEmpty());
        QCOMPARE(idx.localMatches().first().toMap().value(QStringLiteral("localKind")).toString(),
                 QStringLiteral("calc"));
    }

    void tabAppsOnly()
    {
        // tab=apps: solo categoría apps (sin ajustes, ficheros ni web).
        NimbusIndex idx;
        QElapsedTimer t;
        t.start();
        idx.searchLocal(QStringLiteral("kate"), QStringLiteral("apps"));
        const qint64 ms = t.elapsed();
        QVERIFY(!idx.localMatches().isEmpty());
        for (const QVariant &v : idx.localMatches())
            QCOMPARE(v.toMap().value(QStringLiteral("category")).toString(),
                     QStringLiteral("apps"));
        qInfo("latency-tab-apps: %lldms results=%d", ms, idx.localMatches().size());
        QVERIFY2(ms < 50, qPrintable(QStringLiteral("tab=apps tardó %1ms").arg(ms)));
    }

    // F6-T09 (G1): contratos 0/1/2 resultados cuyas formas colapsaban el
    // preview QML (TypeError con índice -1 transitorio del ListView).
    void previewContracts()
    {
        const QByteArray oldHome = qgetenv("HOME");
        const QByteArray oldXdg = qgetenv("XDG_DATA_DIRS");
        QTemporaryDir home;
        QVERIFY(home.isValid());
        qputenv("HOME", home.path().toUtf8());
        qputenv("XDG_DATA_DIRS", QStringLiteral(NIMBUS_FIXTURES).toUtf8());
        NimbusIndex idx;
        // 0: gibberish en tab=apps (sin acción web) → lista vacía.
        idx.searchLocal(QStringLiteral("9z8x7q2w"), QStringLiteral("apps"));
        QVERIFY2(idx.localMatches().isEmpty(), "gibberish en apps debe dar 0");
        // 1: solo la acción web.
        idx.searchLocal(QStringLiteral("zzzzzsinmatch"), QString());
        QCOMPARE(idx.localMatches().size(), 1);
        QCOMPARE(idx.localMatches().first().toMap()
                     .value(QStringLiteral("localKind"))
                     .toString(),
                 QStringLiteral("web"));
        // 2: cálculo + web.
        idx.searchLocal(QStringLiteral("2+2"), QString());
        QCOMPARE(idx.localMatches().size(), 2);
        QCOMPARE(idx.localMatches().first().toMap()
                     .value(QStringLiteral("localKind"))
                     .toString(),
                 QStringLiteral("calc"));
        qputenv("HOME", oldHome);
        if (oldXdg.isEmpty())
            qunsetenv("XDG_DATA_DIRS");
        else
            qputenv("XDG_DATA_DIRS", oldXdg);
    }

    void settingsWifi()
    {
        // Runner Ajustes en vivo: "wifi" debe dar el KCM de red.
        NimbusIndex idx;
        QElapsedTimer t;
        t.start();
        idx.searchLocal(QStringLiteral("wifi"), QStringLiteral("actions"));
        const qint64 ms = t.elapsed();
        QVERIFY(!idx.localMatches().isEmpty());
        bool hasSetting = false;
        for (const QVariant &v : idx.localMatches()) {
            const QVariantMap m = v.toMap();
            if (m.value(QStringLiteral("localKind")).toString() == QLatin1String("setting"))
                hasSetting = true;
        }
        QVERIFY2(hasSetting, "wifi sin KCM de ajustes");
        qInfo("latency-settings-wifi: %lldms results=%d", ms, idx.localMatches().size());
        QVERIFY2(ms < 50, qPrintable(QStringLiteral("settings tardó %1ms").arg(ms)));
    }

    void filesFixture()
    {
        // Runner Archivos con fixture real (scanRoots) + latencia tab=files.
        QTemporaryDir home;
        QVERIFY(home.isValid());
        QDir().mkpath(home.filePath(QStringLiteral("Documents/proyectos")));
        const QString fix = home.filePath(
            QStringLiteral("Documents/proyectos/informe-fixture-nimbus.odt"));
        QFile f(fix);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("fixture");
        f.close();
        QElapsedTimer t;
        t.start();
        const QList<LocalFile> files = NimbusIndex::scanRoots(
            {home.filePath(QStringLiteral("Documents"))});
        const qint64 scanMs = t.elapsed();
        bool found = false;
        for (const LocalFile &lf : files)
            if (lf.path == fix) found = true;
        QVERIFY2(found, "fixture no indexado por scanRoots");
        qInfo("latency-files-scan: %lldms indexed=%d", scanMs, files.size());
        NimbusIndex idx;
        t.start();
        idx.searchLocal(QStringLiteral("informe-fixture"), QStringLiteral("files"));
        const qint64 ms = t.elapsed();
        qInfo("latency-files-query: %lldms results=%d", ms, idx.localMatches().size());
        QVERIFY2(ms < 50, qPrintable(QStringLiteral("files tardó %1ms").arg(ms)));
    }

    void clipboardFallback()
    {
        // Sin klipper (offscreen/CI): fallback declarado + parser unitario.
        NimbusIndex idx;
        const QVariantList clips = idx.clipboardEntries(QString());
        if (clips.isEmpty())
            qInfo("clipboard: klipper ausente, fallback KRunner (clipboardHistory)");
        else
            qInfo("clipboard: klipper con %d entradas", clips.size());
        const QVariantMap e = NimbusIndex::clipEntry(QStringLiteral("hola mundo"), 0);
        QCOMPARE(e.value(QStringLiteral("category")).toString(), QStringLiteral("clipboard"));
        QCOMPARE(e.value(QStringLiteral("quickKey")).toString(), QStringLiteral("A"));
        QCOMPARE(e.value(QStringLiteral("text")).toString(), QStringLiteral("hola mundo"));
        // Truncado: texto <16384, título ≤80.
        const QVariantMap big = NimbusIndex::clipEntry(QString(20000, 'x'), 1);
        QCOMPARE(big.value(QStringLiteral("localExec")).toString().size(), 16384);
        QCOMPARE(big.value(QStringLiteral("text")).toString().size(), 80);
    }

    // F6-T06: parser tolerante de history2.lst (\\n y NUL, sin vacíos/duplicados).
    void clipHistoryParse()
    {
        const QStringList l = NimbusIndex::parseKlipperHistoryFile(
            QStringLiteral("primera\n\nsegunda\0tercera\nprimera\n  \n"));
        QCOMPARE(l, QStringList({"primera", "segunda", "tercera"}));
        QVERIFY(NimbusIndex::parseKlipperHistoryFile(QString()).isEmpty());
    }

    // F6-T06: filtro sin DBus no rompe (vacío offscreen) y respeta límite.
    void clipFilterNoCrash()
    {
        NimbusIndex idx;
        QVERIFY(idx.clipboardEntries(QStringLiteral("zzz-sin-match-f6")).isEmpty());
        QVERIFY(idx.clipboardEntries(QString()).size() <= 20);
    }

    // F6-T06: copiar al portapapeles y leer de vuelta (round-trip Qt).
    void copyRoundTrip()
    {
        if (!QGuiApplication::clipboard()) QSKIP("sin QClipboard");
        NimbusIndex idx;
        QVERIFY(idx.copyToClipboard(QStringLiteral("f6clip-sonda-123")));
        QCOMPARE(QGuiApplication::clipboard()->text(),
                 QStringLiteral("f6clip-sonda-123"));
        QVERIFY(!idx.copyToClipboard(QString())); // vacío: no copia
        // activateLocal copia el texto COMPLETO de un clip (no el título).
        idx.searchLocal(QStringLiteral("2+2"), QString());
        QVERIFY(idx.activateLocal(0, QStringLiteral("copy")));
    }

    // F6-T06: emoji por nombre, keyword EN y categoría; límite 20.
    void emojiSearch()
    {
        NimbusIndex idx;
        QVariantList m = idx.emojiList(QStringLiteral("sonrisa"), QString());
        QVERIFY(!m.isEmpty());
        QVERIFY(m.first().toMap().value(QStringLiteral("text")).toString()
                .startsWith(QString::fromUtf8("\xF0\x9F\x98\x80")));
        m = idx.emojiList(QStringLiteral("pizza"), QString());
        QVERIFY(!m.isEmpty());
        QVERIFY(m.first().toMap().value(QStringLiteral("text")).toString()
                .startsWith(QString::fromUtf8("\xF0\x9F\x8D\x95")));
        m = idx.emojiList(QString(), QStringLiteral("comida"));
        QVERIFY(!m.isEmpty());
        QVERIFY(m.size() <= 20);
        for (const QVariant &v : m) {
            QCOMPARE(v.toMap().value(QStringLiteral("localKind")).toString(),
                     QStringLiteral("emoji"));
            QVERIFY(v.toMap().value(QStringLiteral("subtext")).toString()
                    .startsWith(QStringLiteral("comida")));
        }
        QVERIFY(idx.emojiList(QStringLiteral("zzz-sin-match"), QString()).isEmpty());
        QCOMPARE(idx.emojiList(QStringLiteral("cafe"), QStringLiteral("caras")).size(), 0);
        const QStringList cats = idx.emojiCategories();
        QVERIFY(cats.contains(QStringLiteral("caras")));
        QVERIFY(cats.contains(QStringLiteral("comida")));
        QVERIFY(cats.contains(QStringLiteral("objetos")));
        QVERIFY(cats.contains(QStringLiteral("simbolos")));
    }

    // F6-T06: recientes persistidas en HOME temporal (máx 12, primero el último).
    void emojiRecentsPersist()
    {
        const QByteArray oldHome = qgetenv("HOME");
        QTemporaryDir home;
        QVERIFY(home.isValid());
        qputenv("HOME", home.path().toUtf8());
        {
            NimbusIndex idx;
            idx.recordEmoji(QString::fromUtf8("\xF0\x9F\x8D\x95")); // pizza
            idx.recordEmoji(QString::fromUtf8("\xF0\x9F\x98\x80")); // sonrisa
            QVariantList r = idx.recentEmojis();
            QCOMPARE(r.size(), 2);
            QCOMPARE(r.first().toMap().value(QStringLiteral("localId")).toString(),
                     QString::fromUtf8("\xF0\x9F\x98\x80"));
        }
        {
            // Nueva instancia, mismo HOME: persiste; vacía lidera el listado.
            NimbusIndex idx2;
            QVariantList r = idx2.recentEmojis();
            QCOMPARE(r.size(), 2);
            QVariantList all = idx2.emojiList(QString(), QString());
            QVERIFY(!all.isEmpty());
            QCOMPARE(all.first().toMap().value(QStringLiteral("localId")).toString(),
                     QString::fromUtf8("\xF0\x9F\x98\x80"));
            for (int k = 0; k < 14; ++k)
                idx2.recordEmoji(QStringLiteral("e%1").arg(k));
            QVERIFY(idx2.recentEmojis().size() <= 12);
        }
        qputenv("HOME", oldHome);
    }

    // F6-T03: folding de acentos + mayúsculas (lógica de acción sin abrir apps).
    void accentFolding()
    {
        QVERIFY(NimbusIndex::fuzzyScore(QStringLiteral("Música"),
                                       QStringLiteral("musica"))
                >= 0);
        QVERIFY(NimbusIndex::fuzzyScore(QStringLiteral("Ratón y touchpad"),
                                       QStringLiteral("raton"))
                >= 0);
        QCOMPARE(NimbusIndex::fuzzyScore(QStringLiteral("Café"),
                                        QStringLiteral("CAFE")),
                 0);
        QCOMPARE(NimbusIndex::fuzzyScore(QStringLiteral("Música"),
                                        QStringLiteral("música")),
                 0);
    }

    // F6-T03: 10 consultas representativas contra NimbusIndex con fixtures
    // aislados (HOME temporal + XDG_DATA_DIRS=tests/fixtures). Sin red, sin
    // abrir apps reales: solo ranking esperado vs obtenido + preview.
    void tenQueriesRanking()
    {
        const QByteArray oldHome = qgetenv("HOME");
        const QByteArray oldXdg = qgetenv("XDG_DATA_DIRS");
        QTemporaryDir home;
        QVERIFY(home.isValid());
        qputenv("HOME", home.path().toUtf8());
        // Fixture de archivo para la consulta 4 (el worker lo indexa).
        QDir().mkpath(home.filePath(QStringLiteral("Documents")));
        QFile doc(home.filePath(QStringLiteral("Documents/informe-nimbus.odt")));
        QVERIFY(doc.open(QIODevice::WriteOnly));
        doc.write("fixture");
        doc.close();
        const QString fixDir = QStringLiteral(NIMBUS_FIXTURES);
        qputenv("XDG_DATA_DIRS", fixDir.toUtf8());
        NimbusIndex idx;
        QTest::qWait(3000); // worker de ficheros sobre HOME temporal
        struct Qry { const char *q, *tab, *expectTop, *expectKind; bool webLast; };
        const Qry qs[] = {
            {"Kate", "", "Kate", "app", false},          // 1 exacta
            {"kat", "", "Kate", "app", false},           // 2 prefijo
            {"kte", "", "Kate", "app", false},           // 3 fuzzy
            {"informe", "files", "informe-nimbus.odt", "file", false}, // 4 archivo
            {"wifi", "actions", nullptr, "setting", false}, // 5 ajuste KCM red
            {"2+2", "", "= 4", "calc", false},           // 6 calculadora
            {"clima manana", "", nullptr, "web", true}, // 7 web (acción final)
            {"zzzzzsinmatch", "", nullptr, "web", true}, // 8 sin resultados: solo web
            {"KATE", "", "Kate", "app", false},          // 9 mayúsculas
            {"musica", "", "Música", "app", false},      // 10 acentos
        };
        for (const Qry &e : qs) {
            idx.searchLocal(QString::fromUtf8(e.q), QString::fromUtf8(e.tab));
            const QVariantList ms = idx.localMatches();
            QVERIFY2(!ms.isEmpty(), qPrintable(QStringLiteral("vacío: %1").arg(e.q)));
            // Preview: todos traen text/category/runner/localKind/Id/Exec.
            for (const QVariant &v : ms) {
                const QVariantMap m = v.toMap();
                QVERIFY(!m.value(QStringLiteral("text")).toString().isEmpty());
                QVERIFY(!m.value(QStringLiteral("category")).toString().isEmpty());
                QVERIFY(!m.value(QStringLiteral("localKind")).toString().isEmpty());
                QVERIFY(!m.value(QStringLiteral("localId")).toString().isEmpty());
                QVERIFY(!m.value(QStringLiteral("localExec")).toString().isEmpty());
            }
            QCOMPARE(ms.first().toMap().value(QStringLiteral("quickKey")).toString(),
                     QStringLiteral("A"));
            const QVariantMap top = ms.first().toMap();
            if (e.expectTop)
                QCOMPARE(top.value(QStringLiteral("text")).toString(),
                         QString::fromUtf8(e.expectTop));
            if (e.expectKind) {
                if (e.webLast) {
                    // Web es acción final (relevancia 0,1): está presente.
                    bool hasWeb = false;
                    for (const QVariant &v : ms)
                        if (v.toMap().value(QStringLiteral("localKind")).toString()
                            == QLatin1String("web"))
                            hasWeb = true;
                    QVERIFY2(hasWeb, "sin acción web");
                } else {
                    QCOMPARE(top.value(QStringLiteral("localKind")).toString(),
                             QString::fromUtf8(e.expectKind));
                }
            }
            qInfo("t03-query: '%s' tab='%s' top='%s' kind='%s' n=%d", e.q, e.tab,
                  qPrintable(top.value(QStringLiteral("text")).toString()),
                  qPrintable(top.value(QStringLiteral("localKind")).toString()),
                  ms.size());
        }
        // Sin resultados: SOLO la acción web (n=1).
        idx.searchLocal(QStringLiteral("zzzzzsinmatch"), QString());
        QCOMPARE(idx.localMatches().size(), 1);
        QCOMPARE(idx.localMatches().first().toMap()
                     .value(QStringLiteral("localKind"))
                     .toString(),
                 QStringLiteral("web"));
        qputenv("HOME", oldHome);
        if (oldXdg.isEmpty())
            qunsetenv("XDG_DATA_DIRS");
        else
            qputenv("XDG_DATA_DIRS", oldXdg);
    }

    // F6-T03: acciones Abrir/Copiar/Revelar (lógica, sin lanzar procesos).
    void localActions()
    {
        const QByteArray oldHome = qgetenv("HOME");
        const QByteArray oldXdg = qgetenv("XDG_DATA_DIRS");
        QTemporaryDir home;
        QVERIFY(home.isValid());
        qputenv("HOME", home.path().toUtf8());
        qputenv("XDG_DATA_DIRS", QStringLiteral(NIMBUS_FIXTURES).toUtf8());
        NimbusIndex idx;
        // Índices inválidos: nunca lanzan nada.
        QVERIFY(!idx.activateLocal(-1));
        QVERIFY(!idx.activateLocal(999));
        QVERIFY(!idx.activateLocal(0)); // sin resultados aún
        // Copiar cálculo: va al portapapeles, no abre nada.
        idx.searchLocal(QStringLiteral("2+2"), QString());
        QVERIFY(!idx.localMatches().isEmpty());
        QVERIFY(idx.activateLocal(0, QStringLiteral("copy")));
        if (QGuiApplication::clipboard())
            QCOMPARE(QGuiApplication::clipboard()->text(), QStringLiteral("4"));
        // Revelar app (no fichero): false, sin lanzar proceso.
        idx.searchLocal(QStringLiteral("Kate"), QString());
        QVERIFY(!idx.localMatches().isEmpty());
        QCOMPARE(idx.localMatches().first().toMap()
                     .value(QStringLiteral("localKind"))
                     .toString(),
                 QStringLiteral("app"));
        QVERIFY(!idx.activateLocal(0, QStringLiteral("reveal")));
        // recordUse persiste frecuencia (sube en ranking de vacío).
        idx.recordUse(QStringLiteral("kate.desktop"));
        idx.searchLocal(QString(), QString());
        bool hasKate = false;
        for (const QVariant &v : idx.localMatches())
            if (v.toMap().value(QStringLiteral("localId")).toString()
                == QLatin1String("kate.desktop"))
                hasKate = true;
        QVERIFY2(hasKate, "recordUse no refleja kate.desktop en sugerencias");
        qputenv("HOME", oldHome);
        if (oldXdg.isEmpty())
            qunsetenv("XDG_DATA_DIRS");
        else
            qputenv("XDG_DATA_DIRS", oldXdg);
    }
};

QTEST_MAIN(TstIndex)
#include "tst_index.moc"
