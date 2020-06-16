FROM node:12

WORKDIR /usr/src/

COPY package.json package.json
COPY yarn.lock yarn.lock

COPY dist dist
RUN ls -las
RUN yarn install  --production

#CMD node ./dist/VaultTest.js
CMD yarn start
