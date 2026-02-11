const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const fs = require('fs');


const messageFilePath = 'baca.txt';
const message = fs.readFileSync(messageFilePath, 'utf8');


const numberFilePath = 'number.txt';
const numbers = fs.readFileSync(numberFilePath, 'utf8').split('\n').map(num => num.trim()).filter(num => num);


const client = new Client({
    authStrategy: new LocalAuth()
});


client.on('qr', (qr) => {
    qrcode.generate(qr, { small: true });
    console.log('Scan QR code ini dengan WhatsApp Anda.');
});

client.on('ready', () => {
    console.log('Client is ready!');

    const sendMessages = () => {
        numbers.forEach((number, index) => {
            setTimeout(() => {
                const chatId = `${number}@c.us`;
                client.sendMessage(chatId, message).then(response => {
                    console.log(`Pesan terkirim ke ${number}`);
                }).catch(err => {
                    console.error(`Gagal mengirim pesan ke ${number}:`, err);
                });
            }, index * 40000); // 20000 ms = 20 detik
        });
    };

    sendMessages();

    setInterval(sendMessages, 3600000); // 3600000 ms = 1 jam
});

// Inisialisasi client
client.initialize();
