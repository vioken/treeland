
#include "outputmanagement.h"

#include <wserver.h>

#include <QObject>
#include <QTest>

class PrimaryOutputTest : public QObject
{
    Q_OBJECT

    WAYLIB_SERVER_NAMESPACE::WServer *m_server = nullptr;

public:
    PrimaryOutputTest(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

private Q_SLOTS:

    void initTestCase()
    {
        m_server = new WAYLIB_SERVER_NAMESPACE::WServer();
    }

    void testCreate()
    {
        QVERIFY(m_server->attach<PrimaryOutputV1>(m_server) != nullptr);
    }

    void verifyPrimaryOutput()
    {
        auto protocol = m_server->findChild<PrimaryOutputV1 *>();
        QVERIFY(protocol != nullptr);
    }

    void cleanupTestCase()
    {
        m_server->deleteLater();
        m_server = nullptr;
    }
};

QTEST_MAIN(PrimaryOutputTest)
#include "main.moc"
