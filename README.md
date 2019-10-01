# Credential Switcher
A PowerShell script to easily switch between credentials to access a smb network share.



### The problem

The number of Ransomware attacks is on the rise. Criminals are turning into cyber criminals as ransomware and virtual currency mining are making it a very profitable activity. When a computer is infected with ransomware, it tries to encrypt all files in the local computer and on the network to cause as much damage as possible.

In many personal and business environments users access information stored on network folders. These folders usually serve as a repository of files. The more data these folders contain, the more valuable they become. 

To minimise the damage that malware could cause if it were to gain access to a computer, the principle of least privilege should be applied, restricting where possible the access rights of users to just those absolutely required. When accessing repositories, users most of the time don't need full read and write permissions; writing is only required when users try to safe file changes or when they need to reorganise the repository.

In the same way that it is recommended that users do not have admin rights on their accounts and use administrator account only when needed, it would be desirable that network users are granted only reading access to repositories and use a separate account with writing permissions when they need to do so.

When Windows connects to a network share using SMB protocol, it establishes a SMB session using the credentials saved or provided when the connection is established. Unfortunately, Windows implementation of the protocol does not allow multiple concurrent connections to the same resource with different credentials.

Attempting to establish a new connection with different credentials results in the following error:

![error 1219 w](https://raw.githubusercontent.com/aorgazf/credential-switcher/master/img/error%201219%20w.png)



Using the `net use` command renders the same results:

![error 1219](https://raw.githubusercontent.com/aorgazf/credential-switcher/master/img/error%201219.png)



The `get-smbconnection` cmdlet shows that there were already connections established under another username:

![get-smbconnection.png](https://raw.githubusercontent.com/aorgazf/credential-switcher/master/img/get-smbconnection.png)



In order to establish a new connection with different credentials all current SMB connections need to be closed first, but Windows does not provide a simple mechanism to close those open connections and switch credentials.



### The solution

A simple PowerShell script that allows the user to temporarily switch to use different credentials with higher permissions to carry out specific tasks and reverts back to the original credentials once the task is completed or automatically, after some time.









In my computer set-up I have a set of folders where I save my photos, my documents.

I generally don't need to modify these files. When I need to work on a file I usually download a copy to my local folder, work on it and when it is ready to be filed, I upload it to my repository.



The best protection is ensuring very frequently backups are being performed and saved in safe locations.

These credentials are stored in the system and can be viewed with Windows Credential Manager.

