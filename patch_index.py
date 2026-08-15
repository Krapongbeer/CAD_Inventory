import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

name_group = '''
        <div class="form-group hidden" id="nameGroup">
          <label for="fullName" class="form-label">ชื่อ-นามสกุล</label>
          <div class="input-wrap">
            <span class="input-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
            </span>
            <input
              id="fullName"
              name="fullName"
              type="text"
              class="form-input"
              placeholder="กรอกชื่อ-นามสกุล"
            />
          </div>
        </div>
'''

# Insert nameGroup before email
content = content.replace('<div class="form-group">', name_group + '\n        <div class="form-group">', 1)

# Add toggle link
toggle_link = '''
      <p class="login-footer-text" style="margin-bottom: 0.5rem;">
        ยังไม่มีบัญชีผู้ใช้? <a href="#" id="toggleAuthMode" style="color: var(--cmu-purple); font-weight: 600;">สมัครสมาชิก</a>
      </p>
'''
content = content.replace('<p class="login-footer-text">', toggle_link + '\n      <p class="login-footer-text">')

# Modify script logic
script_replacement = '''
    let isSignUp = false;

    document.getElementById('toggleAuthMode').addEventListener('click', (e) => {
      e.preventDefault();
      isSignUp = !isSignUp;
      
      const title = document.querySelector('.login-header h1');
      const subtitle = document.querySelector('.login-header p');
      const btnText = document.getElementById('loginBtnText');
      const toggleText = document.getElementById('toggleAuthMode');
      
      if (isSignUp) {
        title.textContent = 'สมัครสมาชิก';
        subtitle.textContent = 'สร้างบัญชีเพื่อเข้าใช้งานระบบ';
        btnText.textContent = 'สมัครสมาชิก';
        toggleText.textContent = 'เข้าสู่ระบบ';
        document.getElementById('nameGroup').classList.remove('hidden');
        document.getElementById('fullName').required = true;
      } else {
        title.textContent = 'ยินดีต้อนรับ';
        subtitle.textContent = 'กรุณาเข้าสู่ระบบเพื่อจัดการข้อมูลครุภัณฑ์';
        btnText.textContent = 'เข้าสู่ระบบ';
        toggleText.textContent = 'สมัครสมาชิก';
        document.getElementById('nameGroup').classList.add('hidden');
        document.getElementById('fullName').required = false;
      }
    });

    document.getElementById('loginForm').addEventListener('submit', async (e) => {
      e.preventDefault();
      
      const email = document.getElementById('email').value;
      const password = document.getElementById('password').value;
      const fullName = document.getElementById('fullName').value;
      const errorMsg = document.getElementById('errorMsg');
      const loginBtn = document.getElementById('loginBtn');
      const loginBtnText = document.getElementById('loginBtnText');
      const loginBtnSpinner = document.getElementById('loginBtnSpinner');

      // Clear error
      errorMsg.textContent = '';
      errorMsg.classList.add('hidden');
      
      // Loading state
      loginBtn.disabled = true;
      loginBtnText.textContent = 'กำลังดำเนินการ...';
      loginBtnSpinner.classList.remove('hidden');

      try {
        let error = null;
        if (isSignUp) {
          const res = await window.CAD.supabase.auth.signUp({
            email,
            password,
            options: { data: { full_name: fullName } }
          });
          error = res.error;
          if (!error) {
            alert('สมัครสมาชิกสำเร็จ กรุณารอผู้ดูแลระบบกำหนดสิทธิ์การเข้าถึง');
            window.location.reload();
            return;
          }
        } else {
          const res = await window.CAD.supabase.auth.signInWithPassword({
            email,
            password
          });
          error = res.error;
        }

        if (error) throw error;
        
        window.location.href = 'dashboard.html';
      } catch (err) {
        errorMsg.textContent = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง หรือเกิดข้อผิดพลาด';
        errorMsg.classList.remove('hidden');
      } finally {
        loginBtn.disabled = false;
        loginBtnText.textContent = isSignUp ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ';
        loginBtnSpinner.classList.add('hidden');
      }
    });
'''

# Replace old submit listener
start = content.find("document.getElementById('loginForm').addEventListener('submit', async (e) => {")
end = content.find("});", start) + 3
content = content[:start] + script_replacement + content[end:]

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated index.html for signup flow')
