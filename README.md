# openamsetup
Bash script that installs and configures openam for quick debug. 

# Notes
The appropriate AM and agent .zip files must be downloaded with an active license from backstage.forgerock.com.
This is more of a template to get you going than anything. 
This will be trickier with newer versions and my new deployment scripts are not in bash.
I made this a long time ago when i was to deploying 13.5.0 alot. How i deploy has completed changed, however for community versions this might still be helpful.


# To install with no config
```sh setup```

# To install with config
```sh setup.sh && sh setup.sh configure```
