/// Build with: flutter build web --dart-define=API_BASE=https://api.yourclinic.com
const apiBase =
    String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8080');

// White-label values: change per client.
const clinicName = 'Motion Physio Clinic';
const clinicTagline = 'Move without pain. Book your physiotherapy visit online.';
const clinicPhone = '+91 98765 43210';
const clinicAddress = '12 Main Road, Vijayawada';
