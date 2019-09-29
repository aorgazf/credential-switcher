# credential-switcher
A PowerShell script to easily switch between credentials on a smb network share



### The problem

The number of Ransomware attacks is on the rise. Criminals are turning into cyber criminals as ransomware and virtual currency mining are making it a very profitable activity.

When a computer is infected with ransomware it tries to encrypt all files in the local computer and on the network to cause as much damage as possible.

In many personal and business environments users access information stored on network folders. These folders usually serve as a repository of files. The more data these folders contain, the more valuable they become.

To minimise the damaged that malware could cause if it were to gain access to a computer, it would be best to apply the principle of least privilege where possible and restrict users access rights to those absolutely required.

When accessing repositories, users most of the time don't need full reading and writing permissions; writing is only required when users try to safe file changes or when they need to reorganise the repository.

In the same way that it is recommended that users do not have admin rights on their accounts and use administrator account only when needed, it would be desirable that network users are granted only reading access to repositories and use a separate account with writing permissions when needed.

When Windows connects to a network share using SMB protocol, it establishes a SMB session using the credentials saved or provided when the connection is established. Unfortunately, Windows implementation of the protocol does not allow multiple concurrent connections to the same resource with different credentials.

If we attempt to establish a new connection with different credentials, net use throws error 1219:

![error 1219w](.\error 1219w.png)

![error 1219](.\error 1219.png)

The `get-smbconnection` cmdlet shows that there were already mul

![get-smbconnection.png](.\get-smbconnection.png)



In my computer set-up I have a set of folders where I save my photos, my documents.

I generally don't need to modify these files. When I need to work on a file I usually download a copy to my local folder, work on it and when it is ready to be filed, I upload it to my repository.





The best protection is ensuring very frequently backups are being performed and saved in safe locations.





These credentials are stored in the system and can be viewed with Windows Credential Manager.

