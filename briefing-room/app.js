const form = document.querySelector("#deploymentForm");
const sidebar = document.querySelector("#sidebar");
const shell = document.querySelector(".app-shell");
const toast = document.querySelector("#toast");
const modal = document.querySelector("#deployModal");
const deployStatus = document.querySelector("#deployStatus");
const deployProgress = document.querySelector("#deployProgress");
const closeDeploy = document.querySelector("#closeDeploy");
const cancelDeploy = document.querySelector("#cancelDeploy");

const fields = {
  hostname: document.querySelector("#hostname"),
  ip: document.querySelector("#ipAddress"),
  cidr: document.querySelector("#cidr"),
  gateway: document.querySelector("#gateway"),
  dns: document.querySelector("#dns"),
  password: document.querySelector("#password"),
  confirmPassword: document.querySelector("#confirmPassword"),
};

const summary = {
  hostname: document.querySelector("#summaryHostname"),
  ip: document.querySelector("#summaryIp"),
  gateway: document.querySelector("#summaryGateway"),
  dns: document.querySelector("#summaryDns"),
  password: document.querySelector("#summaryPassword"),
};

const showToast = (message) => {
  toast.textContent = message;
  toast.classList.add("visible");
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => toast.classList.remove("visible"), 1800);
};

const syncSummary = () => {
  summary.hostname.textContent = fields.hostname.value || "Not set";
  summary.ip.textContent = `${fields.ip.value || "Not set"}${fields.ip.value ? fields.cidr.value : ""}`;
  summary.gateway.textContent = fields.gateway.value || "Not set";
  summary.dns.textContent = fields.dns.value || "Not set";
};

Object.values(fields).forEach((field) => field.addEventListener("input", syncSummary));
fields.cidr.addEventListener("change", syncSummary);

document.querySelector("#sidebarToggle").addEventListener("click", () => {
  sidebar.classList.toggle("collapsed");
  shell.classList.toggle("sidebar-collapsed");
});

document.querySelector("#mobileMenu").addEventListener("click", () => {
  sidebar.classList.toggle("mobile-open");
});

document.querySelectorAll(".nav-item").forEach((item) => {
  item.addEventListener("click", () => {
    document.querySelectorAll(".nav-item").forEach((nav) => nav.classList.remove("active"));
    item.classList.add("active");
    sidebar.classList.remove("mobile-open");
    showToast(`${item.dataset.view} selected`);
  });
});

document.querySelectorAll("[data-toggle-password]").forEach((button) => {
  button.addEventListener("click", () => {
    const input = document.querySelector(`#${button.dataset.togglePassword}`);
    input.type = input.type === "password" ? "text" : "password";
    button.innerHTML = `<i data-lucide="${input.type === "password" ? "eye" : "eye-off"}"></i>`;
    lucide.createIcons();
  });
});

let summaryPasswordVisible = false;
document.querySelector("#revealSummaryPassword").addEventListener("click", (event) => {
  summaryPasswordVisible = !summaryPasswordVisible;
  summary.password.textContent = summaryPasswordVisible ? fields.password.value : "••••••••••••";
  event.currentTarget.innerHTML = `<i data-lucide="${summaryPasswordVisible ? "eye-off" : "eye"}"></i>`;
  lucide.createIcons();
});

document.querySelectorAll("[data-copy]").forEach((button) => {
  button.addEventListener("click", async () => {
    await navigator.clipboard.writeText(button.dataset.copy);
    showToast("Copied to clipboard");
  });
});

document.querySelector("[data-copy-password]").addEventListener("click", async () => {
  await navigator.clipboard.writeText(fields.password.value);
  showToast("Password copied");
});

document.querySelectorAll("[data-file]").forEach((input) => {
  input.addEventListener("change", () => {
    const selected = input.files?.[0]?.name;
    if (!selected) return;
    const key = input.dataset.file;
    document.querySelector(`#${key}Name`).textContent = selected;
    document.querySelector(`#summary${key[0].toUpperCase()}${key.slice(1)}`).textContent = selected;
    showToast(`${selected} selected`);
  });
});

document.querySelectorAll("[data-edit]").forEach((button) => {
  button.addEventListener("click", () => {
    const target = button.dataset.edit === "cert" ? document.querySelector('[data-file="cert"]') : fields[button.dataset.edit];
    target?.focus();
    target?.scrollIntoView({ behavior: "smooth", block: "center" });
  });
});

const validateForm = () => {
  document.querySelectorAll(".field.invalid").forEach((field) => field.classList.remove("invalid"));
  let valid = true;
  [fields.hostname, fields.ip, fields.gateway, fields.dns, fields.password, fields.confirmPassword].forEach((input) => {
    if (!input.value.trim()) {
      input.closest(".field").classList.add("invalid");
      valid = false;
    }
  });
  if (fields.password.value.length < 8 || fields.password.value !== fields.confirmPassword.value) {
    fields.password.closest(".field").classList.add("invalid");
    fields.confirmPassword.closest(".field").classList.add("invalid");
    valid = false;
  }
  const badge = document.querySelector(".status-badge");
  badge.classList.toggle("ready", valid);
  badge.classList.toggle("invalid", !valid);
  badge.innerHTML = `<i data-lucide="${valid ? "circle-check" : "circle-x"}"></i>${valid ? "Ready" : "Review"}`;
  lucide.createIcons();
  return valid;
};

document.querySelector("#validateButton").addEventListener("click", () => {
  showToast(validateForm() ? "Configuration validated" : "Review highlighted fields");
});

document.querySelector("#openDocs").addEventListener("click", () => {
  window.open("../docs/kvm-chef360-lab.md", "_blank");
});

document.querySelector("#notifications").addEventListener("click", () => showToast("No new deployment alerts"));
document.querySelector("#profileButton").addEventListener("click", () => showToast("Signed in as Mike Bomba"));

let deployTimer;
const closeModal = () => {
  window.clearInterval(deployTimer);
  modal.classList.remove("visible");
  modal.setAttribute("aria-hidden", "true");
};

cancelDeploy.addEventListener("click", closeModal);
closeDeploy.addEventListener("click", closeModal);

form.addEventListener("submit", (event) => {
  event.preventDefault();
  if (!validateForm()) {
    showToast("Configuration is not ready");
    return;
  }

  modal.classList.add("visible");
  modal.setAttribute("aria-hidden", "false");
  cancelDeploy.classList.remove("hidden");
  closeDeploy.classList.add("hidden");
  let step = 0;
  const stages = [
    [18, "Validating host configuration…"],
    [38, "Verifying certificate chain…"],
    [62, "Preparing Ubuntu autoinstall…"],
    [82, "Staging Chef 360 configuration…"],
    [100, "Deployment request is ready."],
  ];
  const advance = () => {
    const [progress, message] = stages[step];
    deployProgress.style.width = `${progress}%`;
    deployStatus.textContent = message;
    step += 1;
    if (step === stages.length) {
      window.clearInterval(deployTimer);
      cancelDeploy.classList.add("hidden");
      closeDeploy.classList.remove("hidden");
    }
  };
  advance();
  deployTimer = window.setInterval(advance, 850);
});

syncSummary();
window.addEventListener("DOMContentLoaded", () => lucide.createIcons());
