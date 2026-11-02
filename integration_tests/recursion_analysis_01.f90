! Which procedures the recursion analysis (--fast) proves non-recursive:
! `square` (a leaf, even though it is public and used as a value),
! `fact_of` and `even` (they call recursive procedures but are on no cycle)
! and `helper` (it calls through a dummy procedure, but nothing outside can
! call it back). `fact` and `is_even`/`is_odd` are on cycles, and `apply`
! calls an unknown procedure and can be called from outside, so they stay
! recursive, as does `twice`, a value that calls `apply`.
module recursion_analysis_01_m
implicit none
private
public :: square, apply, twice, fact_of, even
abstract interface
    real function real_fn(x)
        real, intent(in) :: x
    end function
end interface
contains
    real function square(x)
        real, intent(in) :: x
        square = x*x
    end function

    real function apply(f, x)
        procedure(real_fn) :: f
        real, intent(in) :: x
        apply = f(x)
    end function

    real function twice(x)
        real, intent(in) :: x
        twice = apply(square, x) + apply(square, x)
    end function

    integer function fact(n) result(r)
        integer, intent(in) :: n
        if (n <= 1) then
            r = 1
        else
            r = n*fact(n - 1)
        end if
    end function

    integer function fact_of(n)
        integer, intent(in) :: n
        fact_of = fact(n)
    end function

    logical function is_even(n) result(r)
        integer, intent(in) :: n
        if (n == 0) then
            r = .true.
        else
            r = is_odd(n - 1)
        end if
    end function

    logical function is_odd(n) result(r)
        integer, intent(in) :: n
        if (n == 0) then
            r = .false.
        else
            r = is_even(n - 1)
        end if
    end function

    logical function even(n)
        integer, intent(in) :: n
        even = is_even(n)
    end function
end module

program recursion_analysis_01
use recursion_analysis_01_m
implicit none
if (abs(helper(3.0) - 9.0) > 1e-6) error stop 1
if (abs(apply(twice, 2.0) - 8.0) > 1e-6) error stop 2
if (fact_of(5) /= 120) error stop 3
if (.not. even(10) .or. even(7)) error stop 4
print *, "ok"
contains
    real function helper(x)
        real, intent(in) :: x
        helper = apply(square, x)
    end function
end program
