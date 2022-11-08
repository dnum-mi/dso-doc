# Cloud Pi Native

L'offre Cloud Pi Native, portée par le Ministère de l'Intérieur et des Outre-Mer et à visée interministérielle a pour but d'améliorer la qualité applicative tout en améliorant les capacités de déploiement au sein de l'administration.

Cette offre s'appuie sur le [Cloud Pi](https://www.numerique.gouv.fr/services/cloud/cloud-interne/) pour le déploiement des applications dans un cluster OpenShift ainsi que sur une plateforme de déploiement offrant un catalogue de services pour suivre le cycle de vie complet de son projet.

## Concept

La plateforme laisse les développeurs travailler sur leurs dépôts de code source habituels (dépôts externes) en effectuant des synchronisations du code source vers un [Gitlab](https://about.gitlab.com/) hébergé par la plateforme (dépôts internes).
Les synchronisations sont déclenchées par des appels API effectués dans les CI/CD côté développeurs (dépôts externes).
Ces appels API permettent de déclencher auprès de DSO une demande de 'pull' du dépôt qui entrainera le déclenchement d'une autre chaine de CI/CD sur le Gitlab de la plateforme. Cette dernière sera en charge de :

- Lancer les jeux de tests applicatif (unitaires, de bout en bout, ...).
- Effectuer une analyse de la qualité du code source à l'aide d'un [Sonarqube](https://www.sonarqube.org/) hébergé par la plateforme.
- Construire les images de conteneur de l'application.
- Scanner les images et le code source à l'aide de [Trivy](https://aquasecurity.github.io/trivy).
- Stocker ces images dans un [Quay](https://quay.io/) hébergé par la plateforme.
- Déployer les images générées à l'aide d'[ArgoCD](https://argo-cd.readthedocs.io/en/stable/).

## Dépôts de code

La plateforme est construite à partir des dépôts de code suivants:

- Code du socle (déploiement des services & provisionning des espaces projets)
  - <https://github.com/dnum-mi/dso-socle>
- Code de la console (interface utilisateur).
  - <https://github.com/dnum-mi/dso-console>

---

# Utilisation de la plateforme

## Prérequis

### Processus

- Avoir un compte dans le SSO de Cloud Pi Native (à demander à l'équipe DSO).
- Avoir l'url de l'API Gateway (`API_DOMAIN`) (à demander à l'équipe DSO).
- Avoir une clé d'authentification (`CONSUMER_KEY`) auprès de l'API Gateway (à demander à l'équipe DSO).
- Avoir un secret d'authentification (`CONSUMER_SECRET`) auprès de l'API Gateway (à demander à l'équipe DSO).

### Techniques

- L'application déployée doit être conteneurisée (sous la forme de un ou plusieurs conteneurs).
  - Les __*Dockerfile*__ doivent être dans le dépôt pour permettre à la chaine de reconstruire l'application.
  - Les images de bases des __*Dockerfile*__ doivent être accessible publiquement.

- L'application doit se déployer à l'aide de fichiers d'__*Infrastructure As Code*__ [kubernetes](https://kubernetes.io/).
  > Pour le moment nous ne générons pas de fichiers d'infrastructure, c'est donc à la main de l'utilisateur de l'offre.
  > Nous souhaitons ultérieurement mettre à disposition des templates pour couvrir les architectures majoritaires.
  
- Si le dépôt externe est privé, fournir à Cloud Pi Native un jeton d'accès personnel (PAT dans GiHub) avec le scope `repo` permettant de pull le dépôt.
  > Réflexion en cours sur l'amélioration du système de mirroring des dépôts.

## Commander un espace projet

1. Se rendre sur la console Cloud Pi Native.

2. Se connecter à l'aide de vos identifiants SSO Cloud Pi Native.

3. Remplir le formulaire de création de projet.

## Synchroniser les dépôts

1. Se rendre sur la console Cloud Pi Native.

2. Se connecter à l'aide de vos identifiants SSO Cloud Pi Native.

3. Remplir le formulaire de synchronisation des dépôts.

Pour que la synchronisation des dépôts soit effective, suivre ces instructions :

- Un dépôt nommé `<nom_de_votre_project>/<nom_de_votre_project>-mirror` a été créé dans votre projet sur le Gitlab interne de la plateforme. Dans ce dernier se trouve un script `script-mirror.sh` à copier dans votre dépôt externe.
  > Ce script a pour but de déclencher dans la CI/CD externe les appels API de demande de synchronisation des dépôts.

- Récupérer dans le dépôt `<nom_de_votre_project>/<nom_de_votre_project>-mirror` le token `GITLAB_TRIGGER_TOKEN` (`Settings > CI/CD > Pipeline triggers`, au besoin en créer un).

- Ajouter les variables d'environnements suivantes dans les __*secrets*__ de votre CI/CD externe avec les valeurs fournies par l'équipe DSO ou précédemment récupérées:

  | Nom de variable      | Description                                                                  |
  | -------------------- | ---------------------------------------------------------------------------- |
  | API_DOMAIN           | Url de l'API Gateway                                                         |
  | CONSUMER_KEY         | Clé d'authentification de l'application au travers de l'API Gateway          |
  | CONSUMER_SECRET      | Secret d'authentification de l'application au travers de l'API Gateway       |
  | GITLAB_TRIGGER_TOKEN | Token de déclenchement du pipeline de synchronisation dans le GitLab interne |

- Ajouter dans votre CI/CD l'exécution de ce script pour déclencher la synchronisation automatiquement.
  
  *Exemple avec Github :*

  ```yaml
  # Dans un fichier .github/workflows/script-mirror.yaml
  name: Repo sync with Cloud Pi Native

  on:
    push:
      branches:
        - "main"
    workflow_dispatch:

  jobs:
    mirror:
      name: Sync repo with Cloud Pi Native
      runs-on: ubuntu-latest
      steps:
        - name: Checks-out repository
          uses: actions/checkout@v3
        - name: Send a sync request to DSO api
          run: |
            sh ./path/to/script-mirror.sh \
              -a ${{ secrets.API_DOMAIN }} \
              -g ${{ secrets.GITLAB_TRIGGER_TOKEN }} \
              -k ${{ secrets.CONSUMER_KEY }} \
              -s ${{ secrets.CONSUMER_SECRET }}
  ```

- Créer un fichier `.gitlab-ci.yml` à la racine de votre dépôt externe, il sera utilisé par le Gitlab de Cloud Pi Native pour effectuer les divers tests, scans et déploiements du projet.
  > Un outil d'aide à la construction de ce fichier est disponible (Demander à l'équipe DSO).

  >  Si votre dépôt d'origine possède déjà un fichier `.gitlab-ci.yml`, nommer le fichier généré `.gitlab-ci-dso.yml` et modifier dans le dépôt interne de la plateforme le fichier utilisé par la CI/CD pour correspondre au nom donné (`Settings > CI/CD > General pipelines > CI/CD configuration file`).

- Placer vos manifestes Kubernetes dans le dépôt `<nom_de_votre_project>/<nom_de_votre_project>-argo` du Gitlab interne de la plateforme (les placer dans le dossier `base/`).

La synchronisation est maintenant en place et chaque appel API effectué avec le script `script-mirror.sh` entrainera le déclenchement de la chaine DevSecOps.

## Services

| Service   | Description                               |
| --------- | ----------------------------------------- |
| Gitlab    | Hébergement de code et pipeline CI/CD     |
| Vault     | Hébergement de secrets                    |
| Quay      | Hébergement d'image de conteneur          |
| Nexus     | Hébergement d'artefacts                   |
| Sonarqube | Analyse de qualité de code                |
| Argocd    | Outil de déploiement automatique (GitOps) |
