Linux Blue Team Strategies:

1. Reset Root credentials.
   **sudo passwd root**

3. Remove unauthorized users.
   **sudo pkill -u [Username]
   sudo userdel -r [Username]**

5. Before activating the firewall, make sure the services being scored are enabled.
   **sudo ufw status verbose**

   Add SSH:
   **sudo ufw allow 22/tcp**

   sudo ufw allow [Port Number]/tcp

   **sudo systemctl ufw enable**

   Then just make sure its setup:
   **sudo ufw status verbose**

7. Threat Hunt
