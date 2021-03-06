"""
Rules that are not directly needed to generate the main or supplemental figures/data.
"""

# Run QUAST on assemblies in a genome set
# (QUAST isn't installed into environment by default)
rule genome_set_quast:
	input: get_genomes_fasta_dir
	output: directory('extra/quast/{genomeset}')
	threads: workflow.cores
	params:
		files=get_genome_fasta_files,
	shell:
		"""
		quast --fast --silent -o {output} -t {threads} {params[files]}
		"""


# Generate genomes.csv for genome sets 3 and 4.
# These are added to version control so it's not necessary to run normally.
# Also don't actually set the output to replace the original file, we don't want this rule to be run
# automatically when regular rules need the table.
rule set_34_genomes_csv:
	input:
		quast=rules.genome_set_quast.output
	output: 'extra/genomes-csv/{genomeset}.csv'
	wildcard_constraints:
		genomeset='set[34]',
	params:
		files=lambda wc: get_genome_fasta_files(wc),
	run:
		from gambit_pub.download import get_md5
		from gambit.cli.common import strip_seq_file_ext

		results = pd.read_csv(os.path.join(input[0], 'transposed_report.tsv'), sep='\t')

		# QUAST replaces dashses with underscores in file names, replace with original file names
		# but check consistency
		filenames = list(map(os.path.basename, params['files']))
		real_ids = list(map(strip_seq_file_ext, filenames))
		quast_ids = results['Assembly']
		assert all(rid.replace('-', '_') == qid for rid, qid in zip(real_ids, quast_ids))

		# Pull columns from QUAST results
		results = results[['# contigs (>= 0 bp)', 'Total length (>= 0 bp)', 'N50', 'L50']]
		results.columns = ['n_contigs', 'total_length', 'N50', 'L50']
		results.index = pd.Series(real_ids, name='id')

		# Add MD5 hashes and full file names
		results['md5'] = [get_md5(open(f, 'rb')) for f in params['files']]
		results['filename'] = filenames

		results.to_csv(output[0])


def get_fastq_kmers_all_input(wildcards=None):
	from gambit.cli.common import strip_seq_file_ext
	genomes = list(map(strip_seq_file_ext, get_genome_fasta_files('set3', full_path=False)))
	return expand(rules.fastq_kmers.output, genome=genomes)

# Run the fastq_kmers rule for all genomes in set 3
rule fastq_kmers_all:
	input: get_fastq_kmers_all_input
