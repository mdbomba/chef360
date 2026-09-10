# chef-courier-cli Reference

Schedules, executes, and monitors jobs on nodes.

## Job Management

### Create Job
```bash
chef-courier-cli job create --template <job-template.json>
```

### List Jobs
```bash
chef-courier-cli job list
chef-courier-cli job list --status <pending|running|completed|failed>
```

### Get Job Details
```bash
chef-courier-cli job get --id <job-id>
```

### Cancel Job
```bash
chef-courier-cli job cancel --id <job-id>
```

### Get Job Results
```bash
chef-courier-cli job results --id <job-id>
```

## Schedule Management

### Create Schedule
```bash
chef-courier-cli schedule create --job-id <job-id> --cron "0 0 * * *"
```

### List Schedules
```bash
chef-courier-cli schedule list
```

### Delete Schedule
```bash
chef-courier-cli schedule delete --id <schedule-id>
```

## Exception Management (Blackout Windows)

### Create Exception
```bash
chef-courier-cli exception create --name "maintenance" --start "2024-01-01T02:00:00Z" --end "2024-01-01T04:00:00Z"
```

### List Exceptions
```bash
chef-courier-cli exception list
```

## Interpreter Management

### List Interpreters
```bash
chef-courier-cli interpreter list
```

### Get Interpreter Details
```bash
chef-courier-cli interpreter get --name <interpreter-name>
```
