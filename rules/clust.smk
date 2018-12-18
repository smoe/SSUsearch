rule clust:
    input:
        expand('{project}/search/{sample}/{sample}.forclust', project=Project, sample=Samples),
    output:
        '{project}/clust/complete.clust'.format(project=Project),
    params:
        allforclust=lambda wildcards, input: ' '.join(input)
    threads: Java_gc_threads
    conda: 'envs/ssusearch.yaml'
    shell:
        """
        mkdir -p {Project}/clust
        cat {params.allforclust} > {Project}/clust/combined_seqs.afa
        python {Srcdir}/scripts/make-groupfile.py {Project}/clust/{Project}.groups {params.allforclust}

        (cd {Project}/clust
        echo -e "*** Mcclust derep starting..\n"
        Clustering -Xmx{Java_xmx} -XX:+UseParallelOldGC \
            -XX:ParallelGCThreads={Java_gc_threads} \
            derep -a -o derep.fasta temp.mcclust.names temp.txt combined_seqs.afa \
            || ( echo -e "*** mcclust derep failed..\n"; exit 1; )
        rm temp.txt
        #Convert mcclust names to mothur names
        python {Srcdir}/scripts/mcclust2mothur_names_file.py temp.mcclust.names temp.mothur.names

        echo -e "*** preclust starting..\n"
        # output: derep.precluster.fasta, derep.precluster.names
        mothur -q \
            "#set.logfile(name=mothur.log); \
            pre.cluster(fasta=derep.fasta, diffs=1, name=temp.mothur.names)" \
            > /dev/null \
            || ( echo -e "*** mothur pre.cluster failed..\n"; exit 1; )

        #Convert names back to mcclust
        python {Srcdir}/scripts/mothur2mcclust_names_file.py \
            derep.precluster.names {Project}.names

        echo -e "*** Mcclust starting..\n" 
        Clustering -Xmx{Java_xmx} -XX:+UseParallelOldGC \
            -XX:ParallelGCThreads={Java_gc_threads} \
            dmatrix -l 25 -o matrix.bin -i {Project}.names \
            -I derep.precluster.fasta 2> /dev/null \
            || ( echo -e "*** mcclust dmatrix fail.."; exit 1; )

        Clustering -Xmx{Java_xmx} -XX:+UseParallelOldGC \
            -XX:ParallelGCThreads={Java_gc_threads} \
            cluster -m upgma -i {Project}.names -s {Project}.groups \
            -o complete.clust -d matrix.bin 2> /dev/null  \
            || ( echo -e "*** mcclust cluster fail.."; exit 1; )

        echo -e "*** Mccclust finished..\n"
        )
        """

