const jwt = require('jsonwebtoken');

const secret = 'supersecret32characterlong12345';
const payload = {
  role: 'anon',
  iss: 'supabase',
  iat: Math.floor(Date.now() / 1000),
  exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 365) // 1 year
};

const token = jwt.sign(payload, secret);
console.log(token);
