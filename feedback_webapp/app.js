// Firebase Configuration
const firebaseConfig = {
    apiKey: "AIzaSyA4bGMoPIjSbEkvlp6X_lOYklYhoa2UshI",
    authDomain: "kreoassist.firebaseapp.com",
    projectId: "kreoassist",
    storageBucket: "kreoassist.firebasestorage.app",
    messagingSenderId: "13114004380",
    appId: "1:13114004380:web:xxxxx"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();
const auth = firebase.auth();
const provider = new firebase.auth.GoogleAuthProvider();

// DOM Elements
const loginOverlay = document.getElementById('login-overlay');
const loginBtn = document.getElementById('login-btn');
const authErrorEl = document.getElementById('auth-error');
const grid = document.getElementById('feedback-grid');
const avgRatingEl = document.getElementById('avg-rating');
const totalEl = document.getElementById('total-feedback');
const bugCountEl = document.getElementById('bug-count');

// Auth Listener
auth.onAuthStateChanged(user => {
    if (user) {
        if (user.email === "workbhaveshpandey@gmail.com") {
            // Success: Hide login, show dashboard
            loginOverlay.classList.add('hidden');
            initData();
        } else {
            // Wrong Email: Sign out and show error
            auth.signOut();
            authErrorEl.textContent = "Access Denied: " + user.email + " is not an admin.";
            loginOverlay.classList.remove('hidden');
        }
    } else {
        // Not logged in
        loginOverlay.classList.remove('hidden');
    }
});

// Login Action
loginBtn.addEventListener('click', () => {
    auth.signInWithPopup(provider).catch(error => {
        authErrorEl.textContent = error.message;
    });
});

// Fetch and Render Feedback
function initData() {
    db.collection("feedback")
        .orderBy("timestamp", "desc")
        .onSnapshot((snapshot) => {
            renderFeedback(snapshot.docs);
            updateStats(snapshot.docs);
        }, (error) => {
            console.error("Error getting documents: ", error);
            if (error.code === 'permission-denied') {
                loginOverlay.classList.remove('hidden');
                authErrorEl.textContent = "Permission Denied. Please log in as Admin.";
            } else {
                grid.innerHTML = `<div class="loading-state"><p style="color:red">Error loading feedback: ${error.message}</p></div>`;
            }
        });
}

function renderFeedback(docs) {
    if (docs.length === 0) {
        grid.innerHTML = '<div class="loading-state"><p>No feedback yet.</p></div>';
        return;
    }

    grid.innerHTML = '';

    docs.forEach(doc => {
        const data = doc.data();
        const date = data.timestamp ? data.timestamp.toDate().toLocaleDateString() : 'N/A';
        const initial = data.username ? data.username[0].toUpperCase() : '?';

        let catClass = 'cat-general';
        if (data.category === 'Bug Report') catClass = 'cat-bug';
        if (data.category === 'Feature Request') catClass = 'cat-feature';

        const card = document.createElement('div');
        card.className = 'feedback-card';
        card.innerHTML = `
            <div class="card-header">
                <div class="stars">
                    ${getStars(data.rating)}
                </div>
                <span class="category-chip ${catClass}">${data.category}</span>
            </div>
            <p class="message">"${data.message}"</p>
            <div class="card-footer">
                <div class="user-info">
                    <div class="user-avatar">${initial}</div>
                    <span>${data.username}</span>
                </div>
                <span class="timestamp">${date}</span>
            </div>
        `;
        grid.appendChild(card);
    });
}

function updateStats(docs) {
    const total = docs.length;

    // Avg Rating
    const sum = docs.reduce((acc, doc) => acc + (doc.data().rating || 0), 0);
    const avg = total > 0 ? (sum / total).toFixed(1) : "0.0";

    // Bug Count
    const bugs = docs.filter(doc => doc.data().category === 'Bug Report').length;

    totalEl.textContent = total;
    avgRatingEl.textContent = avg;
    bugCountEl.textContent = bugs;
}

function getStars(rating) {
    let stars = '';
    for (let i = 0; i < 5; i++) {
        if (i < rating) {
            stars += '<i class="fa-solid fa-star"></i>';
        } else {
            stars += '<i class="fa-regular fa-star"></i>';
        }
    }
    return stars;
}
