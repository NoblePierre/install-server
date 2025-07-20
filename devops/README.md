# Script d'Initialisation de Serveur Sécurisé

Ce script configure automatiquement un serveur Linux avec des paramètres de sécurité renforcés.

## 🔒 Sécurité

Les paramètres sensibles ne sont plus codés en dur dans le script et doivent être passés en arguments :

- **Port SSH** : Port personnalisé pour SSH
- **Utilisateur** : Nom de l'utilisateur à créer
- **Clé publique SSH** : Votre clé publique SSH complète
- **URL des IP françaises** : URL pour télécharger les plages IP françaises (optionnel)

## 🚀 Utilisation

### Prérequis

1. Avoir une clé SSH publique
2. Être connecté en root sur le serveur
3. Avoir les droits d'exécution sur le script

### Génération d'une clé SSH (si nécessaire)

```bash
# Générer une nouvelle paire de clés SSH
ssh-keygen -t ed25519 -C "votre_email@exemple.com"

# Afficher la clé publique
cat ~/.ssh/id_ed25519.pub
```

### Exécution du script

```bash
# Exemple avec tous les paramètres
sudo ./init-server.sh 2233 admin "ssh-ed25519 AAAA...votre_clé_publique... user@machine"

# Exemple avec URL personnalisée pour les IP françaises
sudo ./init-server.sh 2233 admin "ssh-ed25519 AAAA...votre_clé_publique... user@machine" "https://autre-url.com/fr.zone"
```

### Paramètres

| Paramètre | Description | Exemple |
|-----------|-------------|---------|
| `SSH_PORT` | Port SSH personnalisé | `2233` |
| `NEW_USER` | Nom de l'utilisateur | `admin` |
| `PUBLIC_KEY` | Clé publique SSH complète | `ssh-ed25519 AAAA...` |
| `FR_IP_LIST_URL` | URL des IP françaises (optionnel) | `https://www.ipdeny.com/ipblocks/data/countries/fr.zone` |

## 🛡️ Fonctionnalités de Sécurité

1. **Utilisateur non-root** : Création d'un utilisateur avec privilèges sudo
2. **SSH sécurisé** :
   - Port personnalisé
   - Authentification par clé uniquement
   - Désactivation de l'authentification par mot de passe
   - Désactivation de la connexion root
3. **Firewall UFW** : Configuration automatique
4. **Filtrage géographique** : Seules les IP françaises peuvent se connecter en SSH
5. **Persistance** : Les règles sont sauvegardées et rechargées au démarrage

## ⚠️ Important

- **Gardez votre session SSH actuelle ouverte** jusqu'à avoir vérifié que la nouvelle connexion fonctionne
- **Testez la connexion** avant de fermer votre session actuelle :
  ```bash
  ssh -p 2233 admin@IP_DU_SERVEUR
  ```

## 🔧 Dépannage

Si vous ne pouvez plus vous connecter :

1. Vérifiez que votre clé publique est correcte
2. Vérifiez que le port SSH est correct
3. Vérifiez que votre IP est dans la liste des IP françaises
4. Si nécessaire, connectez-vous via la console du fournisseur pour corriger

## 📝 Exemple Complet

```bash
# 1. Générer une clé SSH (si pas déjà fait)
ssh-keygen -t ed25519 -C "admin@serveur"

# 2. Récupérer la clé publique
cat ~/.ssh/id_ed25519.pub

# 3. Exécuter le script avec vos paramètres
sudo ./init-server.sh 2233 admin "$(cat ~/.ssh/id_ed25519.pub)"

# 4. Tester la connexion
ssh -p 2233 admin@IP_DU_SERVEUR
``` 