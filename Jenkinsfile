pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Quality Checks') {
            parallel {
                stage('vote (Python)') {
                    when {
                        beforeAgent true
                        anyOf {
                            changeset pattern: 'vote/**', comparator: 'GLOB'
                            changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                        }
                    }
                    agent { docker { image 'python:3.12' } }
                    steps {
                        dir('vote') {
                            sh '''
                                mkdir -p reports
                                python -m pip install --user flake8 pytest
                                python -m flake8 . --output-file reports/flake8.txt
                                python -m pytest -q --junitxml=reports/pytest.xml
                            '''
                        }
                    }
                    post {
                        always {
                            junit 'vote/reports/*.xml'
                        }
                    }
                }

                stage('result (Node.js)') {
                    when {
                        beforeAgent true
                        anyOf {
                            changeset pattern: 'result/**', comparator: 'GLOB'
                            changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                        }
                    }
                    agent { docker { image 'node:20' } }
                    steps {
                        dir('result') {
                            sh '''
                                mkdir -p reports
                                npm install
                                npx eslint . -f json -o reports/eslint.json
                                npm test
                            '''
                        }
                    }
                }

                stage('worker (.NET)') {
                    when {
                        beforeAgent true
                        anyOf {
                            changeset pattern: 'worker/**', comparator: 'GLOB'
                            changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                        }
                    }
                    agent { docker { image 'mcr.microsoft.com/dotnet/sdk:8.0' } }
                    steps {
                        dir('worker') {
                            sh '''
                                mkdir -p reports
                                dotnet restore
                                dotnet format --verify-no-changes --report reports/format-report.json
                                dotnet test --logger "trx;LogFileName=reports/test-results.trx"
                            '''
                        }
                    }
                }
            }
        }


        stage('Build') {
            parallel {
                stage('Build vote image') {
                    when {
                        anyOf {
                            changeset pattern: 'vote/**', comparator: 'GLOB'
                            changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                        }
                    }
                    steps {
                        dir('vote') {
                            sh '''
                                docker build -t yassine123432/vote:${BUILD_NUMBER} -t yassine123432/vote:latest .
                            '''
                        }
                    }
                }

                stage('Build result image') {
                    when {
                        anyOf {
                            changeset pattern: 'result/**', comparator: 'GLOB'
                            changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                        }
                    }
                    steps {
                        dir('result') {
                            sh '''
                                docker build -t yassine123432/result:${BUILD_NUMBER} -t yassine123432/result:latest .
                            '''
                        }
                    }
                }

                stage('Build worker image') {
                    when {
                        anyOf {
                            changeset pattern: 'worker/**', comparator: 'GLOB'
                            changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                        }
                    }
                    steps {
                        dir('worker') {
                            sh '''
                                docker build -t yassine123432/worker:${BUILD_NUMBER} -t yassine123432/worker:latest .
                            '''
                        }
                    }
                }
            }
        }

        stage('Trivy DB Update') {
            steps {
                sh '''
                    mkdir -p "$WORKSPACE/.trivycache"
                    docker run --rm \
                      -v "$WORKSPACE/.trivycache:/root/.cache/" \
                      aquasec/trivy:0.58.1 image \
                      --download-db-only
                '''
            }
        }

        stage('Security Check') {
            parallel {
                stage('Scan vote image (Trivy)') {
                    when {
                        anyOf {
                            changeset pattern: 'vote/**', comparator: 'GLOB'
                            changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                        }
                    }
                    steps {
                        dir('vote') {
                            sh '''
                                mkdir -p reports
                                docker run --rm \
                                  -v /var/run/docker.sock:/var/run/docker.sock \
                                  -v "$WORKSPACE/.trivycache:/root/.cache/" \
                                  aquasec/trivy:0.58.1 image \
                                  --skip-db-update \
                                  --severity HIGH,CRITICAL \
                                  --format json \
                                  --output reports/trivy-vote.json \
                                  --exit-code 1 \
                                  yassine123432/vote:${BUILD_NUMBER}
                            '''
                        }
                    }
                }

                stage('Scan result image (Trivy)') {
                    when {
                        anyOf {
                            changeset pattern: 'result/**', comparator: 'GLOB'
                            changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                        }
                    }
                    steps {
                        dir('result') {
                            sh '''
                                mkdir -p reports
                                docker run --rm \
                                  -v /var/run/docker.sock:/var/run/docker.sock \
                                  -v "$WORKSPACE/.trivycache:/root/.cache/" \
                                  aquasec/trivy:0.58.1 image \
                                  --skip-db-update \
                                  --severity HIGH,CRITICAL \
                                  --format json \
                                  --output reports/trivy-result.json \
                                  --exit-code 1 \
                                  yassine123432/result:${BUILD_NUMBER}
                            '''
                        }
                    }
                }

                stage('Scan worker image (Trivy)') {
                    when {
                        anyOf {
                            changeset pattern: 'worker/**', comparator: 'GLOB'
                            changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                        }
                    }
                    steps {
                        dir('worker') {
                            sh '''
                                mkdir -p reports
                                docker run --rm \
                                  -v /var/run/docker.sock:/var/run/docker.sock \
                                  -v "$WORKSPACE/.trivycache:/root/.cache/" \
                                  aquasec/trivy:0.58.1 image \
                                  --skip-db-update \
                                  --severity HIGH,CRITICAL \
                                  --format json \
                                  --output reports/trivy-worker.json \
                                  --exit-code 1 \
                                  yassine123432/worker:${BUILD_NUMBER}
                            '''
                        }
                    }
                }
            }
        }

        stage('Push Images') {
            parallel {
                stage('Push vote image') {
                    when {
                        anyOf {
                            changeset pattern: 'vote/**', comparator: 'GLOB'
                            changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                        }
                    }
                    steps {
                        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_PASSWORD')]) {
                            dir('vote') {
                                sh '''
                                    export DOCKER_CONFIG="$WORKSPACE/.docker-vote"
                                    mkdir -p "$DOCKER_CONFIG"
                                    echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
                                    docker push yassine123432/vote:${BUILD_NUMBER}
                                    docker push yassine123432/vote:latest
                                    docker logout
                                '''
                            }
                        }
                    }
                }

                stage('Push result image') {
                    when {
                        anyOf {
                            changeset pattern: 'result/**', comparator: 'GLOB'
                            changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                        }
                    }
                    steps {
                        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_PASSWORD')]) {
                            dir('result') {
                                sh '''
                                    export DOCKER_CONFIG="$WORKSPACE/.docker-result"
                                    mkdir -p "$DOCKER_CONFIG"
                                    echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
                                    docker push yassine123432/result:${BUILD_NUMBER}
                                    docker push yassine123432/result:latest
                                    docker logout
                                '''
                            }
                        }
                    }
                }

                stage('Push worker image') {
                    when {
                        anyOf {
                            changeset pattern: 'worker/**', comparator: 'GLOB'
                            changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                        }
                    }
                    steps {
                        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_PASSWORD')]) {
                            dir('worker') {
                                sh '''
                                    export DOCKER_CONFIG="$WORKSPACE/.docker-worker"
                                    mkdir -p "$DOCKER_CONFIG"
                                    echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
                                    docker push yassine123432/worker:${BUILD_NUMBER}
                                    docker push yassine123432/worker:latest
                                    docker logout
                                '''
                            }
                        }
                    }
                }
            }
        }

        stage('Deploy to Test') {
            when {
                anyOf {
                    changeset pattern: 'vote/**', comparator: 'GLOB'
                    changeset pattern: 'result/**', comparator: 'GLOB'
                    changeset pattern: 'worker/**', comparator: 'GLOB'
                    changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                }
            }
            steps {
                sh '''
                    kubectl apply -k k8s/overlay/test

                    kubectl set image -n test deployment/vote-deployment vote=yassine123432/vote:${BUILD_NUMBER}
                    kubectl set image -n test deployment/result-deployment result=yassine123432/result:${BUILD_NUMBER}
                    kubectl set image -n test deployment/worker-deployment worker=yassine123432/worker:${BUILD_NUMBER}
                '''
            }
        }

        stage('Verify Test Rollout') {
            when {
                anyOf {
                    changeset pattern: 'vote/**', comparator: 'GLOB'
                    changeset pattern: 'result/**', comparator: 'GLOB'
                    changeset pattern: 'worker/**', comparator: 'GLOB'
                    changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                }
            }
            steps {
                sh '''
                    kubectl rollout status -n test deployment/vote-deployment --timeout=180s
                    kubectl rollout status -n test deployment/result-deployment --timeout=180s
                    kubectl rollout status -n test deployment/worker-deployment --timeout=180s
                    kubectl rollout status -n test deployment/redis-deployment --timeout=180s
                    kubectl rollout status -n test statefulset/postgres-statefulset --timeout=180s
                '''
            }
            post {
                failure {
                    sh '''
                        echo "Test rollout verification failed. Rolling back..."
                        kubectl rollout undo -n test deployment/vote-deployment || true
                        kubectl rollout undo -n test deployment/result-deployment || true
                        kubectl rollout undo -n test deployment/worker-deployment || true

                        kubectl rollout status -n test deployment/vote-deployment --timeout=180s || true
                        kubectl rollout status -n test deployment/result-deployment --timeout=180s || true
                        kubectl rollout status -n test deployment/worker-deployment --timeout=180s || true
                    '''
                }
            }
        }

        stage('Approve Prod Promotion') {
            when {
                anyOf {
                    changeset pattern: 'vote/**', comparator: 'GLOB'
                    changeset pattern: 'result/**', comparator: 'GLOB'
                    changeset pattern: 'worker/**', comparator: 'GLOB'
                    changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                }
            }
            steps {
                input message: 'Promote this build to prod namespace?', ok: 'Promote'
            }
        }

        stage('Deploy to Prod') {
            when {
                anyOf {
                    changeset pattern: 'vote/**', comparator: 'GLOB'
                    changeset pattern: 'result/**', comparator: 'GLOB'
                    changeset pattern: 'worker/**', comparator: 'GLOB'
                    changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                }
            }
            steps {
                sh '''
                    kubectl apply -k k8s/overlay/prod

                    kubectl set image -n prod deployment/vote-deployment vote=yassine123432/vote:${BUILD_NUMBER}
                    kubectl set image -n prod deployment/result-deployment result=yassine123432/result:${BUILD_NUMBER}
                    kubectl set image -n prod deployment/worker-deployment worker=yassine123432/worker:${BUILD_NUMBER}
                '''
            }
        }

        stage('Verify Prod Rollout') {
            when {
                anyOf {
                    changeset pattern: 'vote/**', comparator: 'GLOB'
                    changeset pattern: 'result/**', comparator: 'GLOB'
                    changeset pattern: 'worker/**', comparator: 'GLOB'
                    changeset pattern: 'Jenkinsfile', comparator: 'GLOB'
                }
            }
            steps {
                sh '''
                    kubectl rollout status -n prod deployment/vote-deployment --timeout=180s
                    kubectl rollout status -n prod deployment/result-deployment --timeout=180s
                    kubectl rollout status -n prod deployment/worker-deployment --timeout=180s
                    kubectl rollout status -n prod deployment/redis-deployment --timeout=180s
                    kubectl rollout status -n prod statefulset/postgres-statefulset --timeout=180s
                '''
            }
            post {
                failure {
                    sh '''
                        echo "Prod rollout verification failed. Rolling back..."
                        kubectl rollout undo -n prod deployment/vote-deployment || true
                        kubectl rollout undo -n prod deployment/result-deployment || true
                        kubectl rollout undo -n prod deployment/worker-deployment || true

                        kubectl rollout status -n prod deployment/vote-deployment --timeout=180s || true
                        kubectl rollout status -n prod deployment/result-deployment --timeout=180s || true
                        kubectl rollout status -n prod deployment/worker-deployment --timeout=180s || true
                    '''
                }
            }
        }
    }
}