! `host` is private and passes its internal procedure `inner` to the public
! `apply`; `inner` enters `host` again through the public `run`. The
! recursion analysis (--fast) must keep `host` recursive (it is on a cycle
! through the unknown procedure that `apply` calls), so that each instance
! of `host` gets its own thunk and `inner` sees its own `depth`.
module recursion_analysis_02_m
implicit none
private
public :: run, apply
abstract interface
    integer function int_fn(n)
        integer, intent(in) :: n
    end function
end interface
contains
    integer function apply(f, n)
        procedure(int_fn) :: f
        integer, intent(in) :: n
        apply = f(n)
    end function

    integer function run(depth)
        integer, intent(in) :: depth
        run = host(depth)
    end function

    integer function host(depth) result(r)
        integer, intent(in) :: depth
        r = apply(inner, 10)
    contains
        integer function inner(n)
            integer, intent(in) :: n
            if (depth > 0) then
                inner = n*depth + run(depth - 1)
            else
                inner = 0
            end if
        end function
    end function
end module

program recursion_analysis_02
use recursion_analysis_02_m
implicit none
! 10*3 + 10*2 + 10*1 + 0
if (run(3) /= 60) error stop 1
print *, "ok"
end program
