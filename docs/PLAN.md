# Employee Attendance Management System

## Tech Stack

### Mobile Application

* Flutter

### Admin Panel

* Flutter Web

### Backend

* Node.js (Express.js)

### Database

* MongoDB

---

# Employee Mobile App

## Authentication

* Email and password login
* Secure JWT authentication

---

## Attendance

Employees can:

* Scan an encrypted QR code to mark attendance
* Check In
* Check Out
* Start Break
* End Break

The system will automatically:

* Calculate total working hours
* Calculate break duration
* Maintain attendance history
* Generate monthly attendance summaries
* Detect late arrivals
* Detect early check-outs

### QR Verification

* QR codes contain encrypted data and are validated by the server.
* Each attendance request includes the employee's current GPS location.
* The administrator can configure an office location and an allowed attendance radius (geofence).
* If the employee is outside the configured area, attendance is blocked.
* The server validates both the QR code and the employee's location before recording attendance.

---

## Profile

Employees can view:

* Employee information
* Employee ID
* Department
* Designation
* Contact details

---

## Documents

Employees can:

* Upload identification documents
* Upload company ID cards
* View uploaded documents

---

# Admin Web Panel

## Dashboard

Display:

* Total employees
* Employees present
* Employees absent
* Late arrivals
* Employees on leave
* Average working hours
* Attendance statistics
* Daily, weekly, and monthly attendance reports

---

## Employee Management

Administrators can:

* Add employees
* Edit employee details
* Delete employees
* Import employees from Excel
* Export employee data to Excel
* Manage departments
* Manage designations

---

## Attendance Management

Administrators can:

* View live attendance
* View check-in and check-out logs
* Correct attendance manually
* Approve attendance requests
* Resolve missing check-out records

---

## Office Location Management

Administrators can:

* Configure office latitude and longitude
* Set an allowed attendance radius (geofence)
* Update office location at any time

When an employee scans the QR code:

1. The mobile app retrieves the employee's GPS location.
2. The encrypted QR code and location are sent to the server.
3. The server verifies:

   * QR code validity
   * Employee identity
   * Distance from the configured office location
4. Attendance is recorded only if the employee is within the allowed radius.

---

## Reports

Generate reports for:

* Daily attendance
* Weekly attendance
* Monthly attendance
* Working hours
* Late arrivals
* Early check-outs

Export reports in Excel format.

---

# Security

* Encrypted QR codes
* JWT-based authentication
* Password hashing
* Server-side QR validation
* GPS-based geofencing
* HTTPS for all API communication
* Role-based access control (Admin and Employee)
