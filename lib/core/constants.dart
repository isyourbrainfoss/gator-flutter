/// Application-wide constants (ported from Gator settings.py).
library;

const String appId = 'org.gator.Gator';
const String appName = 'Gator';
const String appVersion = '1.5';
const String crocVersion = '10.4.4';
const String crocBinary = 'croc';
const String codeIsPrefix = 'Code is: ';

const int defaultPort = 0;
const int defaultTransfers = 0;
const String defaultMulticast = '';
const String defaultRelay = '';
const String defaultRelay6 = '';
const String defaultHash = '';
const String defaultCurve = '';

const int crocDefaultPort = 9009;
const int crocDefaultTransfers = 4;
const String crocDefaultMulticast = '239.255.255.250';
const String crocDefaultHash = 'xxhash';
const String crocDefaultCurve = 'p256';

const String legacyRelay = '37.27.244.215:9009';
const String legacyRelay6 = '[2a01:4f9:c013:7b04::1]:9009';

const String settingsStorageKey = 'gator_settings';