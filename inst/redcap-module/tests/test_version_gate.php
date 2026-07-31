<?php
require_once __DIR__ . '/../lib/VersionGate.php';

use UbepProvisioning\VersionGate;

// major extraction, on the version strings the fleet actually serves
ubep_assert_same(17, VersionGate::majorOf('17.0.6'), 'majorOf 17.0.6');
ubep_assert_same(17, VersionGate::majorOf('17.3.3'), 'majorOf 17.3.3');
ubep_assert_same(11, VersionGate::majorOf('11.1.15'), 'majorOf 11.1.15');
ubep_assert_same(13, VersionGate::majorOf('13.11.4'), 'majorOf 13.11.4');
ubep_assert_same(14, VersionGate::majorOf('14.7.5'), 'majorOf 14.7.5');
ubep_assert_same(15, VersionGate::majorOf('15.8.4'), 'majorOf 15.8.4');

// the three regimes, floor = ceiling = 17
ubep_assert_same(
    'sotto_minimo',
    VersionGate::classify('15.8.4', 17, 17),
    'below the floor'
);
ubep_assert_same(
    'collaudata',
    VersionGate::classify('17.0.6', 17, 17),
    'inside the window'
);
ubep_assert_same(
    'non_collaudata',
    VersionGate::classify('18.0.0', 17, 17),
    'above the ceiling'
);

// every version in the fleet at 2026-08-01, against floor 17
foreach (['11.1.15', '13.11.4', '14.3.14', '14.7.5', '15.8.1', '15.8.4'] as $old) {
    ubep_assert_same(
        'sotto_minimo',
        VersionGate::classify($old, 17, 17),
        "fleet version $old is below the floor"
    );
}
foreach (['17.0.6', '17.3.3', '17.0.10'] as $inside) {
    ubep_assert_same(
        'collaudata',
        VersionGate::classify($inside, 17, 17),
        "$inside is inside the window"
    );
}

// 17.0.10 against 17.0.6 is the trap a string comparison falls into. Comparing
// majors sidesteps it entirely: both are 17, so the gate never has to order
// them. The assertion stays as a guard against someone "improving" the gate
// into a full-version comparison.
ubep_assert_same(
    VersionGate::classify('17.0.6', 17, 17),
    VersionGate::classify('17.0.10', 17, 17),
    'patch level does not change the regime'
);

// a two-major window, as during a breaking wave
ubep_assert_same(
    'collaudata',
    VersionGate::classify('17.0.6', 17, 18),
    'lower major of a two-major window'
);
ubep_assert_same(
    'collaudata',
    VersionGate::classify('18.2.0', 17, 18),
    'upper major of a two-major window'
);
ubep_assert_same(
    'non_collaudata',
    VersionGate::classify('19.0.0', 17, 18),
    'above a two-major window'
);
