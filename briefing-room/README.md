# Chef 360 Deployment Control Plane

A self-contained responsive deployment configuration interface for the reviewed
Chef 360 KVM lab workflow.

Serve the repository root and open `/briefing-room/`:

```bash
python3 -m http.server 8080
```

The current deployment and validation actions are interactive frontend previews.
They do not invoke the repository's KVM scripts or modify infrastructure.
