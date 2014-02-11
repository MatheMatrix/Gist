import argparse
import sys

print 'sys.argv: ', sys.argv
parser = argparse.ArgumentParser()
parser.add_argument('echo', help='echo the string you are use here')
parser.add_argument('square',
                    help = 'display a square of given number',
                    type = int )
args = parser.parse_args()
print args
print args.echo
print args.square**2
