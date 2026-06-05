const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('Hello World! This is running from an optimized container.');
});

app.listen(PORT, () => {
  console.log(`Server is up and listening on port ${PORT}`);
});