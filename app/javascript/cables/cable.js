import { createConsumer } from "@rails/actioncable"

let consumer;

function createChannel(...args) {
  if (!consumer) {
    consumer = createConsumer();
  }

  return consumer.subscriptions.create(...args);
}

export default createChannel;
