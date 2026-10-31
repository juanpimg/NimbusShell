// tst_index — unit tests del índice local Nimbus (F6-T02).
// fuzzy, calculadora (precedencia/errores), parser .desktop, perf 10k.
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
        const QVariantList clips = idx.clipboardEntries();
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
};

QTEST_MAIN(TstIndex)
#include "tst_index.moc"
