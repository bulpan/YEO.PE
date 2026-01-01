const fs = require('fs');
const path = require('path');

try {
    const configPath = path.join(__dirname, '../config/firebase-service-account.json');
    if (!fs.existsSync(configPath)) {
        console.log('❌ File not found at:', configPath);
        process.exit(1);
    }

    const content = fs.readFileSync(configPath, 'utf8');
    const config = JSON.parse(content);

    console.log('✅ JSON Parse Successful');
    console.log('Project ID:', config.project_id);
    console.log('Client Email:', config.client_email);

    const key = config.private_key;
    if (!key) {
        console.log('❌ private_key is MISSING');
        process.exit(1);
    }

    console.log('Key Length:', key.length);
    console.log('Starts with Header:', key.startsWith('-----BEGIN PRIVATE KEY-----'));
    console.log('Ends with Footer:', key.endsWith('-----END PRIVATE KEY-----\n'));

    // Check for actual newlines
    const hasRealNewlines = key.includes('\n');
    const hasEscapedNewlines = key.includes('\\n'); // Literal \n chars which is bad if not parsed

    console.log('Has Real Newlines (\\n):', hasRealNewlines);
    console.log('Has Literal Escaped Newlines (\\\\n):', hasEscapedNewlines);

    // If it's a valid PEM, it should be printable (with newlines)
    const lines = key.split('\n').length;
    console.log('Line Count (by \\n):', lines);

    if (lines < 5) {
        console.log('⚠️ WARNING: Private key seems to have too few lines. It might be a single line string. PEM keys should be multiline.');
        if (hasEscapedNewlines) {
            console.log('💡 TIP: The file might contain literal "\\n" characters instead of actual line breaks. Node.js JSON.parse handles \\n automatically, but if you copy-pasted as string literal, it might be double escaped.');
        }
    } else {
        console.log('✅ Private key structure looks correct (multiline PEM).');
    }

} catch (e) {
    console.error('❌ Error:', e.message);
}
