<?php
// inst/redcap-module/tests/test_account_reader.php
require_once __DIR__ . '/../lib/AccountReader.php';

use UbepProvisioning\AccountReader;

ubep_assert_same(500, AccountReader::LIMIT, 'the cap is 500 names per call');

$righe = [[
    'username' => 'carla.inventata@ubep.unipd.it',
    'user_creation' => '2026-10-20 09:00:00',
    'user_firstvisit' => '2026-10-20 09:15:00',
    'user_lastlogin' => null,
    'user_firstactivity' => '',
    'user_lastactivity' => '0000-00-00 00:00:00',
]];
$roma = AccountReader::shape(
    ['Carla.Inventata@ubep.unipd.it', 'nessuno@ubep.unipd.it',
     'carla.inventata@ubep.unipd.it '],
    $righe, 'Europe/Rome'
);
ubep_assert_same(2, count($roma), 'un nome ripetuto con altre maiuscole e\' una voce');
ubep_assert_same('Carla.Inventata@ubep.unipd.it', $roma[0]['username'], 'il nome resta come chiesto');
ubep_assert_same(true, $roma[0]['exists'], 'revisione 3: maiuscole diverse, stessa persona');
ubep_assert_same('2026-10-20T07:15:00Z', $roma[0]['user_firstvisit'], 'ora legale di Roma, UTC+2');
ubep_assert_same('2026-10-20T07:00:00Z', $roma[0]['user_creation'], 'anche la creazione e\' in UTC');
ubep_assert_same(null, $roma[0]['user_lastlogin'], 'null resta null');
ubep_assert_same(null, $roma[0]['user_firstactivity'], 'stringa vuota e\' null');
ubep_assert_same(null, $roma[0]['user_lastactivity'], 'revisione 4: la data zero e\' null');
ubep_assert_same('nessuno@ubep.unipd.it', $roma[1]['username'], 'l\'ordine chiesto si conserva');
ubep_assert_same(false, $roma[1]['exists'], 'un nome assente ha la sua voce');
ubep_assert_same(null, $roma[1]['user_firstvisit'], 'e nessuna data');
ubep_assert_same(null, $roma[1]['user_creation'], 'nemmeno la creazione');

// A name asked with padding is the same person as the padding-free row.
$spazi = AccountReader::shape([' Carla.Inventata@ubep.unipd.it  '], $righe, 'UTC');
ubep_assert_same(' Carla.Inventata@ubep.unipd.it  ', $spazi[0]['username'], 'anche con gli spazi, il nome resta come chiesto');
ubep_assert_same(true, $spazi[0]['exists'], 'gli spazi ai bordi non fanno un assente');

// A row that REDCap stores with other capitals still matches.
$maiuscole = AccountReader::shape(
    ['carla.inventata@ubep.unipd.it'],
    [array_merge($righe[0], ['username' => 'Carla.Inventata@ubep.unipd.it'])],
    'UTC'
);
ubep_assert_same(true, $maiuscole[0]['exists'], 'il confronto vale anche per il nome della riga');

$utc = AccountReader::shape(['carla.inventata@ubep.unipd.it'], $righe, 'UTC');
ubep_assert_same('2026-10-20T09:15:00Z', $utc[0]['user_firstvisit'], 'edc03 scrive in UTC');

$inverno = AccountReader::shape(
    ['carla.inventata@ubep.unipd.it'],
    [array_merge($righe[0], ['user_firstvisit' => '2026-12-01 08:00:00'])],
    'Europe/Rome'
);
ubep_assert_same('2026-12-01T07:00:00Z', $inverno[0]['user_firstvisit'], 'ora solare di Roma, UTC+1');

ubep_assert_same([], AccountReader::shape([], $righe, 'UTC'), 'nessun nome, nessuna voce');

// The empty list is answered without a query: this suite defines no db_query(),
// so a call to it would be a fatal error.
ubep_assert_same([], AccountReader::read([]), 'una lista vuota non interroga il database');

// The query asks for the normalized names, once each, escaped one by one.
$sql = AccountReader::selectSql(
    ['Carla.Inventata@ubep.unipd.it', 'carla.inventata@ubep.unipd.it ', "d'ario@ubep.unipd.it"],
    function (string $name): string {
        return addslashes($name);
    }
);
ubep_assert_true(
    strpos($sql, "username in ('carla.inventata@ubep.unipd.it', 'd\\'ario@ubep.unipd.it')") !== false,
    'la select chiede i nomi senza spazi, in minuscolo, una volta sola, con l\'escape'
);
ubep_assert_true(
    strpos($sql, 'from redcap_user_information') !== false
        && strpos($sql, 'user_lastactivity') !== false,
    'la select legge le cinque colonne di redcap_user_information'
);
