import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

export const sendChatNotification = functions.firestore
  .document("messages/{messageId}")
  .onCreate(async (snapshot) => {
    const messageData = snapshot.data();

    const text = messageData.text;
    const sender = messageData.sender;
    const receiver = messageData.receiver;

    const userDoc = await admin.firestore().collection("users").doc(receiver).get();

    if (!userDoc.exists) {
      console.log("❌ Kullanıcı bulunamadı:", receiver);
      return;
    }

    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log("❌ Kullanıcının FCM token'ı yok.");
      return;
    }

    const payload = {
      notification: {
        title: "Yeni Mesaj",
        body: text,
      },
      token: fcmToken,
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log("✅ Bildirim gönderildi:", response);
    } catch (error) {
      console.error("❌ Bildirim hatası:", error);
    }
  });
