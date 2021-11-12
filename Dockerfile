FROM node:12

ENV PORT 3000
ADD . /menou

WORKDIR /menou
RUN yarn && yarn build

CMD ["node", "dist"]