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

If you are going to use configure make sure you modify the configuration switch to have the cookie domain set properly, otherwise you will not be able to authenticate after configuration.

# The obvious
Not an official Forgerock script, this is meant for dev environments only. 
I give no support to this at all. Fork it and do what you like.
