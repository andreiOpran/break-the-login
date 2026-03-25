# Break the Login – Attacking and Securing Authentication (AuthX)

[![Security CI (SAST/DAST)](https://github.com/andreiOpran/break-the-login/actions/workflows/security.yml/badge.svg)](https://github.com/andreiOpran/break-the-login/actions/workflows/security.yml)


## Project Objective
The goal of this project is to understand how an authentication and authorization system is attacked in practice and how it must be correctly implemented to resist real-world attacks.

This project simulates a real-world scenario at the fictional company **AuthX**, which develops an internal application used by employees to manage sensitive tickets. The app is assessed through a dual-role approach:
1. **Security Tester:** Identifying and demonstrating vulnerabilities via automated Proof-of-Concept (PoC) scripts.
2. **Developer:** Repairing the implementation and hardening the system against the demonstrated attacks.

---

## Git Branches: The Tale of Two Systems

This repository serves as an interactive lab environment and is split into two main branches:

*   **`vulnerable` branch:** Contains the initial, flawed implementation of the system. It showcases common amateur mistakes in authentication, authorization, and session management. All PoC scripts will successfully compromise the application on this branch.
*   **`fixed` branch:** Contains the hardened, secure implementation. The codebase has been refactored to align with industry best practices. Running the PoC scripts on this branch will result in blocked attacks (e.g., `401 Unauthorized`, `403 Forbidden`, `404 Not Found`, or `429 Too Many Requests`).

---

## Vulnerabilities Addressed & Fixes Implemented

We systematically tracked down and mitigated a sequence of critical vulnerabilities:

| ID | Category | The Vulnerability (v1) | The Fix (v2) |
| :--- | :--- | :--- | :--- |
| **4.1** | **Weak Password Policy** | System accepted trivial passwords like `password` or `123`. | Implemented strict regex complexity requirements (length, uppercase, lowercase, numbers, special characters). |
| **4.2** | **Insecure Password Storage** | Passwords stored securely using MD5 without salts. | Migrated to robust **bcrypt** algorithm with automatic random salting. |
| **4.3** | **No Rate Limiting (Brute Force)** | Attackers could guess passwords infinitely without consequence. | Implemented a TRIPLE shield: IP Rate Limiting, Account-Targeted Limiting, and a hard DB-level Account Lockout (15 mins) after 7 failed attempts. |
| **4.4** | **User Enumeration** | API returned different responses ("User not found" vs "Wrong password"). | Unified all error messages to `Invalid credentials` and utilized dummy-hashing to establish uniform response latency (preventing timing attacks). |
| **4.5** | **Insecure Session Management** | Tokens lived for a week and remained heavily valid post-logout (Token Re-use). | Implemented **Stateless Token Versioning**. The DB increments a `token_version` on login/logout/password resets, instantly killing all previously issued JWTs globally. |
| **4.6** | **Insecure Password Reset** | Tokens were theoretically predictable (`MD5(email)`) and infinitely reusable. | Swapped to cryptographically secure `secrets.token_urlsafe(32)` tokens with a strict 60-minute expiration and a single-use (`used=True`) database constraint. |
| **IDOR** | **Insecure Direct Object Reference** | `GET/PATCH/DELETE` endpoints blindly grabbed items by `ticket_id`. | Imforced rigid database-level scoping (`Ticket.owner_id == current_user.id`), returning safe `404 Not Found` errors to mask data existence. |
| **RBAC** | **Broken Access Control** | Any logged-in `ANALYST` could override a Ticket's `status`. | Implemented Role-Based Access Control, strictly ensuring only `MANAGER` roles can perform status overriding. |

---

## Running the Project & Lab Setup

This application is designed to be hosted on one machine (e.g., your host OS or an "App VM") and attacked from a separate machine (e.g., a "Kali Linux VM"). The `run.sh` script automatically bridges these environments, detects your host IP, and routes it to the `poc/config.sh` file so the attack scripts always know where to point.

### Prerequisites
* Python 3.10+
* `pip`, `venv`
* A hypervisor with a bridged networking interface (e.g., `virbr1`) if running in a multi-VM lab.

### Launching the Application
The `run.sh` script handles virtual environment creation, installation of dependencies, dynamic IP binding, and (optionally) Linux firewall configurations.

```bash
# To dynamically host the app and configure the firewall (requires sudo):
./run.sh fw

# To quickly spin up the app (skipping firewall setup updates):
./run.sh fast
```
*(When started, `run.sh` will print the specific URL, such as `http://192.168.200.1:8082`, where the app is hosted and accessible to your attack VM.)*

### Testing Vulnerabilities (PoCs)
Inside the `poc/` directory, you will find bash scripts crafted to automate the attacks for each vulnerability listed above. Since `run.sh` automatically updates `poc/config.sh` with the correct server IP, you can run these scripts directly from your attacking VM without manual configuration.

1. Ensure the server is running on your Host/App VM.
2. From your Attacker VM (or locally), execute any of the bash scripts:
   ```bash
   # Example: Test if session tokens survive a logout event
   bash poc/4.5_token_reuse_after_logout/KALI_login_logout_use_token.sh
   
   # Example: Test IDOR data leaks
   bash poc/IDOR/KALI_idor_tickets.bash
   ```
3. Switch between the `vulnerable` and `fixed` git branches on the App VM to watch the attacks succeed and fail, respectively.
