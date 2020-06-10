#include <Crypto.h>
#include <SHA512.h>
#include <string.h>
#include <RNG.h>

const unsigned short RELAY_PIN = 12;
const unsigned short KEY_PIN = 2;
const unsigned short SWITCH_PIN = 3;

bool RELAY_STATUS = false;
bool KEY_STATUS = false;
bool SWITCH_STATUS = false;

bool DC_RELAYCTRL_NEW_STATUS = false;

uint8_t challenge_data[32];
char challenge_str[32 * 2 + 1];

uint8_t response_plain[32];
char response_plain_str[32 * 2 + 1];

SHA512 sha512;
uint8_t response_hash[512 / 8];

uint8_t recv_hash[512 / 8];
size_t recv_bytes = 0;

const char secret[32+1] = "changemeCDEFGHIJKLMNOPQRSTUVWXYZ";

uint8_t in_buffer[64];

const uint8_t magic_bytes[4] = { 0xDA, 0x7A, 0xC1, 0xBE };

unsigned long challenge_time = 0;
bool challenge_running = false;

void setup() {
  RNG.begin("dc-relayctrl");
  add_noise();
  
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(KEY_PIN, INPUT);
  pinMode(SWITCH_PIN, INPUT);
  Serial.begin(9600);
  Serial.println("DCRELAYCTRL v0.1");
}

void loop() {
  if ((digitalRead(RELAY_PIN) == HIGH) != RELAY_STATUS) digitalWrite(RELAY_PIN, RELAY_STATUS ? HIGH : LOW);
  
  KEY_STATUS = (digitalRead(KEY_PIN) == HIGH);
  if (KEY_STATUS) {
    SWITCH_STATUS = (digitalRead(SWITCH_PIN) == HIGH);
    RELAY_STATUS = SWITCH_STATUS;
  }
  else {
    // listen for command: DA 7A C1 BE [new status: 00 for OFF, other for ON]
    listen_for_serial();
    if (!memcmp(in_buffer, magic_bytes, 4) && !challenge_running) {
      DC_RELAYCTRL_NEW_STATUS = !(!in_buffer[4]);
      memset(in_buffer, 0, 32);
      if (DC_RELAYCTRL_NEW_STATUS == RELAY_STATUS) Serial.println(RELAY_STATUS ? "ON" : "OFF");
    }
    
    // if command would change status: send challenge
    if (DC_RELAYCTRL_NEW_STATUS != RELAY_STATUS) {
      if (challenge_running) {
        if (millis() - challenge_time > 60 * 1000UL) {
          challenge_running = false;
          DC_RELAYCTRL_NEW_STATUS = RELAY_STATUS;
        }
      }
      else {
        challenge_time = millis();
        challenge_running = true;
        RNG.rand(challenge_data, 32);
        uint8_t_to_string(challenge_data, challenge_str, 32);
        for (unsigned short i = 0; i < 32; i++) response_plain[i] = challenge_data[i] ^ secret[i];
        uint8_t_to_string(response_plain, response_plain_str, 32);
        calculate_hash(&sha512, response_plain_str);
      }
      Serial.println(challenge_str);
    }
    
    if (challenge_running) { // if command would change status: listen for response
      if (!memcmp(in_buffer, response_hash, 64)) {
        RELAY_STATUS = DC_RELAYCTRL_NEW_STATUS;
        Serial.println(RELAY_STATUS ? "ON" : "OFF");
        challenge_running = false;
      }
    }
  }
  delay(1000);
}

void calculate_hash(Hash *hash, char *data) {
  size_t size = strlen(data);
  size_t posn, len;

  hash->reset();
  for (posn = 0; posn < size; posn += 64) {
    len = size - posn;
    if (len > 64) len = 64;
    hash->update(data + posn, len);
  }
  hash->finalize(response_hash, sizeof(response_hash));
}

void uint8_t_to_string(uint8_t *src, char *dest, size_t len) {
  char hexchars[16] = "0123456789abcdef"; 
  
  for (int i = 0; i < len; i++) {
    dest[2*i] = hexchars[src[i] / 16];
    dest[2*i+1] = hexchars[src[i] % 16];
  }
}

void string_to_uint8_t(char *src, uint8_t *dest, size_t len) {
  for (size_t i = 0; i < len; i += 2) {
    dest[i/2] = (char_to_uint8_t(src[i]) << 4);
    dest[i/2] |= (char_to_uint8_t(src[i + 1]));
  }
}

uint8_t char_to_uint8_t(const char src) {
  if (src >= '0' && src <= '9') return src - '0';
  if (src >= 'A' && src <= 'F') return src - 'A' + 10;
  if (src >= 'a' && src <= 'f') return src - 'a' + 10;
  return -1;
}

void add_noise() {
  for (unsigned short i = 0; i < 32; i++) {
    RNG.stir(analogRead(A0),1,8);
    delayMicroseconds(50);
  }
}

void listen_for_serial() {
  unsigned short bytes_read = 0;
  if (!Serial.available()) return;
  while (Serial.available()) {
    if (!(bytes_read % 2)) in_buffer[bytes_read / 2] = char_to_uint8_t(Serial.read()) << 4;
    else in_buffer[bytes_read / 2] |= char_to_uint8_t(Serial.read());
    if (++bytes_read >= 128) break;
  }
}
