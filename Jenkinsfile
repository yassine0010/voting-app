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
                                python -m venv .venv
                                . .venv/bin/activate
                                python -m pip install flake8 pytest
                                python -m flake8 app.py --output-file reports/flake8.txt || true
                                if find . -maxdepth 3 -type f -name 'test_*.py' | grep -q . || find . -maxdepth 3 -type f -name '*_test.py' | grep -q .; then
                                    python -m pytest -q --junitxml=reports/pytest.xml
                                else
                                    echo "No tests found in vote/, skipping pytest"
                                fi
                            '''
                        }
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: 'vote/reports/*.xml'
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
                                mkdir -p "$WORKSPACE/.npm-cache"
                                export npm_config_cache="$WORKSPACE/.npm-cache"
                                npm install
                                npx eslint . -f json -o reports/eslint.json || true
                                npm test || true
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
                                mkdir -p "$WORKSPACE/.dotnet" "$WORKSPACE/.nuget/packages"
                                export DOTNET_CLI_HOME="$WORKSPACE/.dotnet"
                                export NUGET_PACKAGES="$WORKSPACE/.nuget/packages"
                                export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
                                export DOTNET_CLI_TELEMETRY_OPTOUT=1
                                dotnet restore
                                dotnet format --verify-no-changes --report reports/format-report.json || true
                                dotnet test --logger "trx;LogFileName=reports/test-results.trx" || true
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
                                mkdir -p reports
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
                                mkdir -p reports
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
                                mkdir -p reports
                                docker build -t yassine123432/worker:${BUILD_NUMBER} -t yassine123432/worker:latest .
                            '''
                        }
                    }
                }
            }
        }

        // stage('Trivy DB Update') {
        //     steps {
        //         sh '''
        //             mkdir -p "$WORKSPACE/.trivycache"
        //             docker run --rm \
        //               -v "$WORKSPACE/.trivycache:/root/.cache/" \
        //               aquasec/trivy:0.58.1 image \
        //               --download-db-only
        //         '''
        //     }
        // }

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
                        sh '''
                            mkdir -p vote/reports
                            docker run --rm \
                              -v /var/run/docker.sock:/var/run/docker.sock \
                              -v "$WORKSPACE/.trivycache:/root/.cache/" \
                              -v "$WORKSPACE/vote/reports:/output" \
                              aquasec/trivy:0.58.1 image \
                              --skip-db-update \
                              --severity HIGH,CRITICAL \
                              --format json \
                              --output /output/trivy-vote.json \
                              --exit-code 0 \
                              yassine123432/vote:${BUILD_NUMBER}
                        '''
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'vote/reports/trivy-vote.json', allowEmptyArchive: true
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
                                  -v "$PWD/reports:/output" \
                                  aquasec/trivy:0.58.1 image \
                                  --skip-db-update \
                                  --severity HIGH,CRITICAL \
                                  --format json \
                                  --output /output/trivy-result.json \
                                  --exit-code 0 \
                                  yassine123432/result:${BUILD_NUMBER}
                            '''
                        }
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'result/reports/trivy-result.json', allowEmptyArchive: true
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
                                  -v "$PWD/reports:/output" \
                                  aquasec/trivy:0.58.1 image \
                                  --skip-db-update \
                                  --severity HIGH,CRITICAL \
                                  --format json \
                                  --output /output/trivy-worker.json \
                                  --exit-code 0 \
                                  yassine123432/worker:${BUILD_NUMBER}
                            '''
                        }
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'worker/reports/trivy-worker.json', allowEmptyArchive: true
                        }
                    }
                }
            }
        }

        stage('Push Imagess') {
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
withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
    sh '''
        echo "Testing kbeconfig..."
        kubectl --kubeconfig=$KUBECONFIG get nodes

        kubectl --kubeconfig=$KUBECONFIG apply -k k8s/overlay/test

        kubectl --kubeconfig=$KUBECONFIG set image -n test deployment/vote-deployment vote=yassine123432/vote:${BUILD_NUMBER}
        kubectl --kubeconfig=$KUBECONFIG set image -n test deployment/result-deployment result=yassine123432/result:${BUILD_NUMBER}
        kubectl --kubeconfig=$KUBECONFIG set image -n test deployment/worker-deployment worker=yassine123432/worker:${BUILD_NUMBER}
    '''
}
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