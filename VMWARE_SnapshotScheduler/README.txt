How to schedule snapshots:

1. Add the names of the VM's you want to snapshot to the Input.txt file
2. Launch VMWare_SnapshotScheduler.ps1 under your user account OR an account that has write permissions to the script directory
3. Follow on-screen prompts
4. A Job file will be created at .\Jobs

	The naming convention for Job Files is yyyy_MM_dd__HH_mm.TXT, where the timestamp in the job file name is the time at which the job file was created by the Scheduler script, NOT the time that the Actual snapshots will take place.

	The Job file simply consists of 1 entry / line for each machine you intended with the following format

		vCenterServerName	IntendedSnapshotCaptureTime	IntendedSnapshotName	MachineName

______________________________


VMWare_SnapshotExecutor.ps1 is the script that actually captures the snapshots. This is achieved by having it run as a scheduled task every 30 mins on a server that can communicate with the desired vCenter Servers

The task must run under an account that has the necessary permissions to do snapshots, etc

Alternatively, you can manually run it under your account if you have permissions.

It works by looking for Job Files at .\Jobs, and loops through each line in the file, creating the needed snapshots.

If an intended machine is powered on, gracefully shuts down the OS and waits for 60s to make sure the system is powered down, then takes the snapshot and after that powers on the VM again.

If the initial Shutdown-VMGuest command fails, tries to Hard Stop the VM using Stop-VM. IF Stop-VM also fails, proceeds to the next machine in the job file.

If the VM hasn't powered Off, after the 60s wait time, the script will wait 180s more. If after that the machine is still powered on, it will attempt a hard stop. If the hard stop fails, will skip to the next machine.

Once all machines are done, it DELETES the job file to prevent snapshotting of the same machines twice in a row.

The $SnapshotBufferTime variable, declared in the beginning of the script, defines when the snapshot taking process is allowed to begin. It's set to 1hr by default, meaning:

	a) Scheduled task runs, Script detects a pending Job
	b) Script checks what the current time is at execution
		b1) If the time is less than the $SnapshotBufferTime, the snapshot process is allowed to begin
		b2) If the time is more than the $snapshotBufferTime, the snapshot process doesn't begin

All actions done by either the Scheduler or Executor are logged at .\Logs\SchedulerLog.log and .\Logs\Executor.log