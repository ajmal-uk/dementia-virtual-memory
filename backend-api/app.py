import os
import tempfile
import base64
import requests
from flask import Flask, request, jsonify, render_template
import numpy as np
from deepface import DeepFace
from PIL import Image

app = Flask(__name__)

class SimpleFacerec:
    def __init__(self, model_name="ArcFace"):
        self.known_face_encodings = []
        self.known_face_data = []
        self.model_name = model_name

    def _save_base64_image(self, base64_str):
        img_data = base64.b64decode(base64_str)
        tmp_file = tempfile.NamedTemporaryFile(suffix=".jpg", delete=False)
        tmp_file.write(img_data)
        tmp_file.close()
        return tmp_file.name

    def _safe_path(self, img_path):
        if img_path.lower().endswith(".webp"):
            temp_path = img_path.replace(".webp", "_temp.jpg")
            Image.open(img_path).convert("RGB").save(temp_path)
            return temp_path
        return img_path

    def add_member(self, member):
        try:
            img_path = self._save_base64_image(member['memberImage'])
            safe_img = self._safe_path(img_path)

            embedding = DeepFace.represent(
                img_path=safe_img,
                model_name=self.model_name,
                enforce_detection=False
            )[0]["embedding"]

            embedding = np.array(embedding)
            self.known_face_encodings.append(embedding)
            # Store the original URL instead of base64 data
            self.known_face_data.append({
                "memberName": member.get("memberName"),
                "memberRelation": member.get("memberRelation"),
                "memberImageUrl": member.get("memberImageUrl")  # Store URL instead of base64
            })

            if safe_img != img_path:
                os.remove(safe_img)
            os.remove(img_path)

            return True
        except Exception as e:
            print(f"[WARNING] Could not encode member {member.get('memberName')}: {e}")
            return False

    def match_image(self, query_img_path, tolerance=0.45):
        try:
            safe_img = self._safe_path(query_img_path)
            embedding = DeepFace.represent(
                img_path=safe_img,
                model_name=self.model_name,
                enforce_detection=False
            )[0]["embedding"]

            query_encoding = np.array(embedding)
            if safe_img != query_img_path:
                os.remove(safe_img)

        except Exception as e:
            print(f"[ERROR] Could not process query image: {e}")
            return None, None

        if not self.known_face_encodings:
            print("[ERROR] No known faces loaded")
            return None, None

        similarities = [
            np.dot(query_encoding, known) / (
                np.linalg.norm(query_encoding) * np.linalg.norm(known)
            )
            for known in self.known_face_encodings
        ]

        best_match_index = np.argmax(similarities)
        best_score = similarities[best_match_index]

        if best_score >= (1 - tolerance):
            return self.known_face_data[best_match_index], best_score
        else:
            return None, best_score


@app.route('/')
def home():
    return render_template('api-test.html')


@app.route('/recognize', methods=['POST'])
def recognize():
    members_str = request.form.get("members")
    image_url = request.form.get("imageUrl")

    if not members_str:
        return jsonify({"error": "members field is required"}), 400
    if not image_url:
        return jsonify({"error": "imageUrl field is required"}), 400

    import json
    try:
        members = json.loads(members_str)
        if not isinstance(members, list):
            raise ValueError("members must be a list")
    except Exception as e:
        return jsonify({"error": f"Invalid members JSON: {e}"}), 400

    sfr = SimpleFacerec()

    loaded_members = 0
    for member in members:
        # Check for both memberImage (base64) and memberImageUrl (URL)
        if all(k in member for k in ("memberName", "memberImage", "memberRelation")):
            # Add the original URL to the member data
            member["memberImageUrl"] = member.get("memberImageUrl", "")
            if sfr.add_member(member):
                loaded_members += 1
        else:
            print(f"[WARNING] Skipping incomplete member data: {member}")

    if loaded_members == 0:
        return jsonify({"error": "No valid member images loaded"}), 400

    # Download test image from imageUrl
    try:
        resp = requests.get(image_url, stream=True, timeout=10)
        resp.raise_for_status()
        tmp_query_file = tempfile.NamedTemporaryFile(suffix=".jpg", delete=False)
        for chunk in resp.iter_content(chunk_size=8192):
            tmp_query_file.write(chunk)
        tmp_query_file.close()
    except Exception as e:
        return jsonify({"error": f"Could not download imageUrl: {e}"}), 400

    matched_member, confidence = sfr.match_image(tmp_query_file.name)

    os.remove(tmp_query_file.name)

    if matched_member:
        return jsonify({
            "matchFound": True,
            "memberName": matched_member["memberName"],
            "memberRelation": matched_member["memberRelation"],
            "memberImageUrl": matched_member["memberImageUrl"],  # Return URL instead of base64
            "confidence": float(confidence)
        })
    else:
        return jsonify({
            "matchFound": False,
            "message": "No matches found",
            "confidence": float(confidence) if confidence is not None else None
        })


if __name__ == '__main__':
    app.run(debug=True)