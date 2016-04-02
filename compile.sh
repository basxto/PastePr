#!/bin/sh
cd js

rm all.js
#cat lib/*.js *.js > all.fromJs.js
cat lib/*.coffee *.coffee | coffee --compile -m --stdio > all.fromCoffee.js

cat license.header all.from{Js,Coffee}.js > all.js
#cat license.header > all.js
#hjsmin all.fromJs.js >> all.js
#hjsmin all.fromCoffee.js >> all.js
rm all.from{Js,Coffee}.js
