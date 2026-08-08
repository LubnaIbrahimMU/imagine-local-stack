#!/usr/bin/env python3
"""
Generates the Senior DevOps Interview Master Guide & Production Hardening Plan PDF.
"""
from fpdf import FPDF
import os

class PDFGuide(FPDF):
    def header(self):
        self.set_font("Helvetica", "B", 10)
        self.set_text_color(100, 100, 100)
        self.cell(0, 10, "Imagine / MyPro - Senior DevOps Interview & Hardening Guide", border=False, align="R")
        self.ln(12)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(150, 150, 150)
        self.cell(0, 10, f"Page {self.page_no()}/{{nb}}", align="C")

def generate_pdf():
    pdf = PDFGuide()
    pdf.alias_nb_pages()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=15)

    # Title
    pdf.set_font("Helvetica", "B", 18)
    pdf.set_text_color(24, 43, 73)
    pdf.cell(0, 12, "Senior DevOps Engineer Interview Master Guide", ln=True, align="L")
    
    pdf.set_font("Helvetica", "I", 11)
    pdf.set_text_color(80, 80, 80)
    pdf.cell(0, 8, "End-to-End Enterprise Kubernetes, GitOps, Vault & Storage Architecture", ln=True, align="L")
    pdf.ln(5)

    def add_section(title):
        pdf.set_font("Helvetica", "B", 13)
        pdf.set_text_color(24, 43, 73)
        pdf.set_fill_color(235, 242, 250)
        pdf.cell(0, 9, f"  {title}", ln=True, fill=True)
        pdf.ln(3)

    def add_body(text):
        pdf.set_font("Helvetica", "", 9.5)
        pdf.set_text_color(40, 40, 40)
        pdf.multi_cell(0, 5, text)
        pdf.ln(3)

    def add_code(code_text):
        pdf.set_font("Courier", "", 8.5)
        pdf.set_text_color(30, 30, 30)
        pdf.set_fill_color(245, 245, 245)
        lines = code_text.strip().split("\n")
        for l in lines:
            pdf.cell(0, 4.5, f"  {l}", ln=True, fill=True)
        pdf.ln(3)

    # Section 1
    add_section("1. System Architecture & Component Inventory")
    add_body(
        "The MyPro stack is an enterprise-grade Kubernetes application platform running on a multi-namespace "
        "architecture (dev, uat, prd). Key components include:\n"
        "- Ingress: NGINX Ingress Controller with SSL termination & cert-manager Cloudflare DNS-01 validation.\n"
        "- Vault: HashiCorp Vault KV-v2 engine with Vault Agent Injector sidecar.\n"
        "- Registry: Private self-hosted Harbor registry (vharbor.aliien.uk) with automated TLS cert trust.\n"
        "- Storage: MinIO Object Storage with python boto3 SDK integration.\n"
        "- CI/CD & GitOps: GitHub Actions build-and-push pipeline + Argo CD App-of-Apps deployment pattern."
    )

    # Section 2
    add_section("2. Step-by-Step Command Execution Log")
    add_body("A. Configure Host Docker Trust for Harbor Self-Signed Certificates:")
    add_code("sudo /home/lu/Downloads/int/tasks/mypro/scripts/setup-docker-harbor-trust.sh")
    
    add_body("B. Unseal Vault & Seed Centralized Secrets:")
    add_code(
        "kubectl exec -n vault vault-0 -- vault operator unseal 'bnUcz6yIXclgBQWDJnCt9CgshSh+mMjqdmj4R2kxEg27'\n"
        "kubectl exec -n vault vault-0 -- vault operator unseal 'nUx2MmvXaJU3MwFY3pKiGMaGs3oTv2yMp15zUP5RmKxL'\n"
        "kubectl exec -n vault vault-0 -- vault operator unseal '6QGwCW63oqnJlJJfm0zjuebNcn/EYAih0alEESkdF7/U'\n"
        "/home/lu/Downloads/int/tasks/mypro/infrastructure/vault/seed-vault-secrets.sh"
    )

    add_body("C. Build, Tag, and Push Application Images to Harbor:")
    add_code("/home/lu/Downloads/int/tasks/mypro/scripts/build-and-push-images.sh vharbor.aliien.uk pro4 v2.0.1")

    add_body("D. Deploy Application Stack via Helm to Development Environment:")
    add_code(
        "helm dependency build /home/lu/Downloads/int/tasks/mypro/helm/charts/umbrella-app\n"
        "helm upgrade --install dev-app /home/lu/Downloads/int/tasks/mypro/helm/charts/umbrella-app \\\n"
        "  -n dev --create-namespace -f /home/lu/Downloads/int/tasks/mypro/helm/values/values-dev.yaml"
    )

    add_body("E. Verify MinIO Object Storage Operations:")
    add_code("python3 /home/lu/Downloads/int/tasks/mypro/scripts/test-backend-minio-integration.py")

    # Section 3
    add_section("3. Senior DevOps Interview Technical Talking Points")
    add_body(
        "Q: How do you handle secrets management without exposing sensitive credentials in Git?\n"
        "A: We use HashiCorp Vault KV-v2 combined with the Vault Agent Injector sidecar. Pods annotate their "
        "Vault role and path (secret/data/dev/database). Vault Agent automatically renders credentials into "
        "/vault/secrets/db-config at runtime. The Flask application sources this file dynamically, keeping plain-text "
        "passwords completely out of Helm values and source control.\n\n"
        "Q: How is GitOps structured to prevent infrastructure vs application drift?\n"
        "A: We follow the Argo CD App-of-Apps design pattern. Root application root-application.yaml monitors "
        "gitops/apps/. We split manifests into gitops/apps/infrastructure/ (Harbor, MinIO, Vault) and "
        "gitops/apps/applications/ (dev/uat/prd microservices). This enforces strict boundary isolation."
    )

    # Section 4
    add_section("4. Future Upgrade & Production Hardening Roadmap")
    add_body(
        "1. Argo CD Image Updater: Integrate Argo CD Image Updater to eliminate manual image tag commits in GitHub Actions.\n"
        "2. Vault Auto-Unseal: Transition Vault from manual Shamir keys to AWS KMS / GCP KMS Transit Auto-Unseal.\n"
        "3. Network Policies: Enforce default-deny egress/ingress network policies per namespace.\n"
        "4. Observability: Add ServiceMonitors & Alertmanager Slack integration for proactive container crash alerts."
    )

    out_path = "/home/lu/Downloads/int/tasks/mypro/Senior_DevOps_Interview_Master_Guide.pdf"
    pdf.output(out_path)
    print(f"[+] Successfully generated PDF guide at: {out_path}")

if __name__ == "__main__":
    generate_pdf()
