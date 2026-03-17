FROM node:18-alpine

WORKDIR /app

RUN addgroup -S app && adduser -S app -G app

COPY package*.json ./
RUN npm install

COPY . .

RUN chown -R app:app /app

USER app

CMD ["node", "server.js"]