# Stego Mob
Stego Mob is an Android steganography app that enables users to securely embed and extract hidden data within images. Such that the concealed data remains invisible to the naked eye, ensuring privacy and confidentiality.



## Features
- Hide Text with Password: Embed sensitive text or passwords inside images with AES encryption to protect data from unauthorized access.

- Hide Images with Password: Conceal one image within another.

- Hide Documents with Password: Securely embed documents inside images for safe storage and sharing.

- Even if the hidden data is extracted from the image using advanced techniques, it remains secure and unreadable without the correct password because AES encryption.
  


## How it works

### User Uploads a cover Image 
- Users uploads a cover image and select the data they want to hide — it can be text, an another image, or a document.
  






### Data Encryption with AES
- The app encrypts the data using AES (Advanced Encryption Standard) with a password provided by the user. This ensures that only someone with the correct password can decrypt and access the hidden data.

### Data Conversion to Bytes
- The encrypted data is converted into a sequence of bytes to strore inside image.

### Embedding Data Using LSB Steganography 
- The app hides these encrypted bytes into the least significant bits (LSB) of the pixels of a cover image. This process subtly alters the image without noticeably changing its appearance.

### Stego Image Creation
- The result is a stego image — visually indistinguishable from the original but containing the hidden encrypted data.
  
 





### Data Extraction & Decryption
- When extracting, the app reads the LSBs from the stego image pixels, reconstructs the encrypted data bytes, decrypts them using the user’s password(same password provide dduring embedding), and recovers the original hidden data.



### Other Features
- Register/Login with Email and password
- User password update and user logout
- Dark mode/light mode




![stego_0](https://github.com/user-attachments/assets/7e9c1f56-b2bc-4894-b1c4-9ac76a658755)


![stego_1](https://github.com/user-attachments/assets/357cf330-3be1-4455-b0b4-f4902568807d)



![stego_2](https://github.com/user-attachments/assets/070c705c-491c-4664-a117-504178b579a0)



![stego_3](https://github.com/user-attachments/assets/32ebb0a4-e2f0-4c97-b93c-2cccf276d5c1)



![stego_4](https://github.com/user-attachments/assets/cf5396ab-5bb4-4941-a22e-b0ea3113ec99)



![stego_9](https://github.com/user-attachments/assets/d5796166-8fa1-4688-9cfa-b77b1e93a209)


 ![stego_5](https://github.com/user-attachments/assets/f3a18e05-459a-4b1e-b15e-39376429d14c)



  ![stego_6](https://github.com/user-attachments/assets/5dab94a4-733a-4e1c-8097-dc6d11aa8f55)


  ![stego_7](https://github.com/user-attachments/assets/01c76bd4-749a-4953-b143-0d0ef7698e71)


  ![stego_10](https://github.com/user-attachments/assets/ae62e7f4-4549-445e-abd2-85d39001a6ab)


  ![WhatsApp Image 2025-08-12 at 09 08 43_ceb5d824](https://github.com/user-attachments/assets/4d763311-79e7-4e79-8ea5-5f70bc2dc21f)

  
  
 ![WhatsApp Image 2025-08-12 at 09 08 43_adbdc72d](https://github.com/user-attachments/assets/19108163-70c5-4b4a-801e-a540e7f88651)
 
 

 ![WhatsApp Image 2025-08-12 at 09 08 43_8189ae56](https://github.com/user-attachments/assets/b8022e49-fb95-48c3-8b30-61751266afbe)


  



